
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
      @status = nil
      @args = parse_args(args)
      @cmd = "#{cmd} #{@args}"
    end
  end

  attr_reader :status
  attr_reader :input, :output

  def initialize
    raise "abstract"
  end

  def exec
    pid = self.exec_

    _pid, @status = Process.waitpid2(pid) # sync
    if @status != 0
      raise BadStatus.new(@status)
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

  def awk
    Rubish::Awk.new(self)
  end

  # TODO HMMM.. sometimes for reasons unknown this
  # method prints "17" (SIGCHLD). I can't figure
  # out why or where.
  ## I think it's ruby's default signal handler
  ## doing something funny?
  def each_
    # send output lines to block if command is not already redirected
    if output.nil?
      r,w = IO.pipe
      @output = w
      pid = self.exec_
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
        _pid, @status = Process.waitpid2(pid)
      end
      if @status != 0
        raise BadStatus.new(@status)
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
      acc << (block_given? ? yield(l) : l )
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
