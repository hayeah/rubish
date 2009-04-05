class Rubish::Executable

  # encapsulates the context of an executing job.
  # handles cleanup
  class Job < Rubish::JobControl::Job
    
    class << self
      def start(exe)
        self.new(exe)
      end
    end

    class JobIO
      attr_reader :thread
      attr_reader :io
      attr_reader :auto_close
      
      def initialize(io,auto_close,thread)
        @io = io
        @auto_close = auto_close
        @thread = thread
      end

      def close
        if auto_close
          io.close
        else
          #io.flush if io.stat.writable?
          #io.flush rescue true # try flushing
        end
        
        if thread
          begin
            thread.join
          ensure
            if thread.alive?
              thread.kill
            end
          end
        end
      end
    end

    attr_accessor :exitstatus
    attr_accessor :ios
    
    def initialize(exe)
      # prepare_io returns an instance of JobIO
      i = prepare_io(exe.i || $stdin,"r")
      o = prepare_io(exe.o || $stdout,"w")
      e = prepare_io(exe.err || $stderr,"w")
      @ios = [i,o,e]
      pids = exe.exec_with(i.io,o.io,e.io)
      super(pids)
    end
    
    # threads
    # ios

    def wait(&block)
      r = nil
      Rubish.session.job_control.wait(self)
      cleanup
      return r
    end

    def kill
      Rubish.session.job_control.kill(self)
    end

    def cleanup
      @ios.each do |io|
        io.close
      end
    end

    # sorry, this is pretty hairy. This method
    # instructs how exec should handle IO. (whether
    # IO is done in a thread. whether it needs to be
    # closed. (so on))
    #
    # an io could be
    # String: interpreted as file name
    # Number: file descriptor
    # IO: Ruby IO object
    # Block: executed in a thread, and a pipe connects the executable and the thread.
    def prepare_io(io,mode)
      # if the io given is a block, we execute it in a thread (passing it a pipe)
      raise "invalid io mode: #{mode}" unless mode == "w" || mode == "r"
      result =
        case io
        when $stdin, $stdout, $stderr
          [io, false, nil]
        when String
          path = File.expand_path(io)
          raise "path is a directory" if File.directory?(path)
          [File.new(path,mode), true, nil]
        when Integer
          fd = io
          [IO.new(fd,mode), false,nil]
        when IO
          [io, false,nil] 
        when Proc
          proc = io
          r,w = IO.pipe
          # if we want to use a block to
          # (1) input into executable
          #   - return "r" end from prepare_io, and
          #   the executable use this and standard
          #   input.
          #   - let the thread block writes to the "w" end
          # (2) read from executable
          #   - return "w" from prepare_io
          #   - let thread reads from "r"
          return_io, thread_io =
            case mode
              # case 1
            when "r"
              [r,w]
            when "w"
              # case 2
              [w,r]
            end
          thread = Thread.new do
          begin
            proc.call(thread_io)
          ensure
            thread_io.close
          end
        end
          [return_io, true, thread]
        else
          raise "not a valid input: #{io}"
        end
      return JobIO.new(*result)
    end

  end

  attr_reader :working_directory

  # only changes working directory for this executable
  def cd(dir)
    @working_directory = dir
    self
  end

#   def awk(address=nil,&block)
#     if block
#       Rubish::Awk.new(self).act(&block)
#     else
#       Rubish::Awk.new(self)
#     end
#   end

  
#   def sed(address=nil,&block)
#     if block
#       Rubish::Sed.new(self).act(&block)
#     else
#       Rubish::Sed.new(self)
#     end
#   end
  
  def exec!
    if self.working_directory
      Rubish.session.cd(self.working_directory) do
        Job.start(self)
      end
    else
      Job.start(self)
    end
  end

  # TODO catch interrupt here
  def exec
    job = exec!
    job.wait
    job
  end

  def exec_with(i,o,e)
    raise "abstract"
  end

  # methods for io redirection
  def i(io=nil,&block)
    return @__io_in unless io || block
    @__io_in = io || block
    self
  end

  def o(io=nil,&block)
    return @__io_out unless io || block
    @__io_out = io || block
    self
  end

  def err(io=nil,&block)
    return @__io_err unless io || block
    @__io_err = io || block
    self
  end
  
  def io(i=nil,o=nil)
    i(i); o(o)
    self
  end

  def each!
    self.o do |pipe|
      pipe.each_line do |line|
        line.chomp!
        yield(line)
      end
    end
    job = self.exec!
    return job
  end

  def each(&block)
    job = self.each! &block
    job.wait
  end
  
  # acc is the accumulator passed in by reference, and updated destructively.
  def map!(acc,&block)
    job = self.each! do |l|
      acc << (block.nil? ? l : block.call(l))
    end
    return job
  end

  def map(&block)
    acc = []
    job = self.map!(acc,&block)
    job.wait
    return acc
  end

  def head(n=1,&block)
    raise "n should be greater than 0: #{n}" unless n > 0
    self.map do |l|
      if n == 0
        break
      else
        n -= 1
        block ? block.call(l) : l
      end
    end
  end

  def tail(n=1,&block)
    raise "n should be greater than 0: #{n}" unless n > 0
    acc = []
    self.each do |l|
      acc << (block ? block.call(l) : l)
      if acc.size > n
        acc.shift
      end
    end
    return acc
  end

  def first
    head(1).first
  end

  def last
    tail(1).first
  end

  
  
end
