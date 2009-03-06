
class Rubish::Command < Rubish::Executable
  
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

  def exec_with(i,o,e)
    unless pid = Kernel.fork
      # child
      begin
        # dup2 the given i,o,e to stdin,stdout,stderr
        # close all other file 
        Rubish.set_stdioe(i,o,e)
        # exec the command
        Kernel.exec(self.cmd)
      rescue
        puts $!
        Kernel.exit(1)
      end
    end
    return pid
  end

  def awk(fs=nil,&block)
    Rubish::Awk.make(self,fs,&block)
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
