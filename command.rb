
class Rubish::Command < Rubish::Executable
  
  attr_reader :cmd, :args
  attr_reader :quoted # if true, arguments for exec are not shell expanded.
  def initialize(cmd,args)
    @quoted = false
    @args = parse_args(args)
    @cmd = cmd.to_s
  end
  
  def exec_with(i,o,e)
    unless pid = Kernel.fork
      # child
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
        puts $!
        Kernel.exit(1)
      end
    end
    return nil
  end

  def to_s
    self.cmd
  end

  def q
    @quoted = true
    self
  end

  def q!
    @quoted = false
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
    rs.flatten!
    rs
  end

end
