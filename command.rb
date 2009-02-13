
class Rubish::Command
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

  class << self
    def build(cmd,args)
      self.new(cmd,args)
    end
  end
  # sh = Bash.new(cmd,*args)
  # sh.exec
  #
  # for piping
  # sh.out = <io>
  # sh.in = <io>
  attr_reader :exe, :args, :status
  attr_reader :cmd, :opts
  attr_reader :input, :output
  def initialize(cmd,args)
    @exe = cmd
    @status = nil
    @args = args.join " "
    @cmd = "#{exe} #{args}"
  end

  def exec
    pid = self.exec_

    _pid, status = Process.waitpid2(pid) # sync

    if status != 0
      raise BadStatus.new(status)
    end
    return nil
  end

  def exec_
    unless pid = Kernel.fork
      # child
      begin
        $stdin.reopen(input) if input
        $stdout.reopen(output) if output
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

  def each_
    # send output lines to block if command is not already redirected
    if output.nil?
      r,w = IO.pipe
      @output = w
      pid = self.exec_
      w.close
      old_trap = Signal.trap("CHLD") do
        r.close
      end
      Signal.trap("CHLD",&old_trap)
      r.each_line do |l|
        yield(l)
      end
      _pid, status = Process.waitpid2(pid)
      if status != 0
        raise BadStatus.new(status)
      end
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
      acc << yield(l)
    end
    acc
  end

  def to_s
    self.cmd
  end

  def i(i)
    @input = i
    self
  end

  def o(o)
    @output = o
    self
  end
  
  def io(i=nil,o=nil)
    @input = i
    @output = o
    self
  end

end
