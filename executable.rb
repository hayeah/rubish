class Rubish::Executable

  def awk(fs=nil,&block)
    Rubish::Awk.make(self,fs,&block)
  end

  class AbnormalExits < RuntimeError
    attr_reader :statuses
    def initialize(statuses)
      @statuses = statuses
    end

    def to_s
      report = statuses.map { |s| "#{s.pid} => #{s.exitstatus}"}.join ";"
      "<##{self.class}: #{report}>"
    end
  end
  
  # an io could be
  # String: interpreted as file name
  # Number: file descriptor
  # IO: Ruby IO object
  # Block: executed in a thread, and a pipe connects the executable and the thread.
  def exec
    i,o,e = self.i, self.o, self.err
    begin
      i, close_i, thread_i = __prepare_io(i,"r")
      o, close_o, thread_o = __prepare_io(o,"w")
      e, close_e, thread_e = __prepare_io(e,"w")
      # exec_with forks processes that communicate with Rubish via IPCs
      exec_with((i || $stdin), (o || $stdout), (e || $stderr))
      statuses = Process.waitall.map { |r| r[1] }
      bads = statuses.select do |s|
        s if s.to_i != 0 
      end
      if !bads.empty?
        raise AbnormalExits.new(bads)
      end
    ensure
      # i,o,e could've already been closed by an IO thread (when a block is used).
      i.close if close_i && !i.closed?
      o.close if close_o && !o.closed?
      e.close if close_e && !e.closed?
      __wait_thread(thread_i) if thread_i
      __wait_thread(thread_o) if thread_o
      __wait_thread(thread_e) if thread_e
    end
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

  def each
    self.pipe_out do |r|
      r.each_line do |l|
        yield(l)
      end
    end
  end

  def map
    acc = []
    self.each do |l|
      acc << (block_given? ? yield(l) : l )
    end
    acc
  end

  def pipe_out
    begin
      old_o = self.o
      r,w = IO.pipe
      self.o(w)
      self.exec
      w.close
      yield(r)
    ensure
      self.o(old_o)
      w.close if !w.closed?
      r.close
    end
  end

  private

  def __wait_thread(thread)
    thread.join(1)
    if thread.alive?
      thread.kill
    end
  end

  # return <#IO>, <#Bool>, <#Thread> || nil
  ## this is only called from Executable#exec, and
  ## exec is responsible to close IO and join thread.
  #
  # sorry, this is pretty hairy. This method
  # instructs how exec should handle IO. (whether
  # IO is done in a thread. whether it needs to be
  # closed. (so on))
  def __prepare_io(io,mode)
    # if the io given is a block, we execute it in a thread (passing it a pipe)
    raise "invalid io mode: #{mode}" unless mode == "w" || mode == "r"
    case io
    when nil
      return nil, false
    when $stdin, $stdout, $stderr
      return io, false
    when String
      path = File.expand_path(io)
      raise "not a file" unless File.file?(path)
      return File.new(path,mode), true
    when Integer
      fd = io
      return IO.new(fd,mode), false
    when IO
      return io, false
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
      return return_io, true, thread
    else
      raise "not a valid input: #{io}"
    end
  end
  
end
