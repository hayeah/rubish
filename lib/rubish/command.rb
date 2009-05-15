
class Rubish::Command < Rubish::UnixExecutable
  
  attr_reader :cmd, :args
  attr_reader :quoted # if true, arguments for exec are not shell expanded.
  def initialize(cmd,args)
    @quoted = false
    @args = args
    @cmd = cmd.to_s
  end
  
  def exec_with(i,o,e)
    normalize_args!
    unless pid = Kernel.fork
      # child
      system_exec(i,o,e)
    else
      return [pid]
    end
  end

  # this method should be called after fork
  def system_exec(i,o,e)
    begin
      # dup2 the given i,o,e to stdin,stdout,stderr
      # close all other file
      Rubish.set_stdioe(i,o,e)
      # exec the command
      if self.quoted
        # use arguments as is
        Kernel.exec self.cmd, *args
      else
        # want shell expansion of arguments
        Kernel.exec "#{self.cmd} #{args.join " "}"
      end
    rescue
      # with just want to kill the child
      # process. When something goes wrong with
      # exec. No cleanup necessary.
      #
      # There's a weird problem with
      # Process.exit(non_zero) raising SystemExit,
      # and that exception somehow reaches the
      # parent process.
      Process.exit!(1)
    end
  end

  def to_s
    self.inspect
  end

  def q
    @quoted = true
    self
  end

  def q!
    @quoted = false
    self
  end

  def +(arg)
    @args << arg
    self
  end

  def %(arg)
    @args = [arg]
    self
  end

  def normalize_args!(args=@args)
    args.map! do |arg|
      case arg
      when Symbol
        "-#{arg.to_s[0..-1]}"
      when Array
        # recursively flatten args
        normalize_args!(arg)
      when String
        arg
      else
        raise "argument to command should be one of Symbol, String, Array "
      end
    end
    args.flatten!
    args
  end

end
