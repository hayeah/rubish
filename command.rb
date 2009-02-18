
class Rubish::Command < Rubish::Executable
  class CommandError < RuntimeError
  end

  class BadStatus < CommandError
    attr_reader :status
    def initialize(status)
      @status = status
    end

    def to_s
      "<##{self.class}: #{status}>"
    end
  end

  class ShellCommand < Rubish::Command
    attr_reader :cmd, :opts
    def initialize(cmd,args)
      super
      @status = nil
      @args = parse_args(args)
      @cmd = "#{cmd} #{@args}"
    end
  end

  attr_reader :status
  attr_reader :input, :output

  def exec
    pid = self.exec_(io_in,io_out,io_err)

    _pid, @status = Process.waitpid2(pid) # sync
    if @status != 0
      raise BadStatus.new(@status)
    end
    return nil
  end

  def exec_(i,o,e)
    unless pid = Kernel.fork
      # child
      begin
        $stdin.reopen(i)
        $stdout.reopen(o)
        $stderr.reopen(e)
        # exec the command
        Kernel.exec(self.cmd)
      rescue
        puts $!
        cmd_name = self.cmd.split.first
        $stderr.puts "#{cmd_name}: command not found"
        Kernel.exit(127) # that's the bash exit status.
      end
    end
    return pid
  end

  def awk(fs=nil,&block)
    Rubish::Awk.make(self,fs,&block)
  end

  # TODO HMMM.. sometimes for reasons unknown this
  # method prints "17" (SIGCHLD). I can't figure
  # out why or where.
  ## I think it's ruby's default signal handler
  ## doing something funny?
  def each_
    r,w = IO.pipe
    pid = self.exec_(io_in,w,w)
    w.close # this is the write end of the forked child

    #       Signal.trap("CHLD") do
    #         puts "child closed"
    #       end
    begin
      r.each_line do |l|
        yield(l)
      end
    ensure
      # in case the block was broken out of.
      #Signal.trap("CHLD","DEFAULT")
      r.close
      _pid, @status = Process.waitpid2(pid)
    end
    if @status != 0
      raise BadStatus.new(@status)
    end
    
    return nil
  end

  def each
    self.each_ do |l|
      Rubish.session.submit(yield(l))
    end
  end

  def map
    acc = []
    self.each_ do |l|
      acc << (block_given? ? yield(l) : l )
    end
    acc
  end

  def to_s
    self.cmd
  end
  
  private

  def parse_args(args)
    rs = args.map do |arg|
      case arg
      when Symbol
        "-#{arg.to_s[0..-1]}"
      when Array
        # recursively flatten args
        parse_args(arg)
      when String
        arg
      else
        raise "argument to command should be one of Symbol, String, Array "
      end
    end
    rs.join " "
  end

end
