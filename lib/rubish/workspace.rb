class Rubish::Workspace < Rubish::Mu

  module Base
    include Rubish::Session::JobControl
    
    def cd(dir,&block)
      if block
        begin
          old_dir = FileUtils.pwd
          FileUtils.cd File.expand_path(dir)
          # hmmm.. calling instance_eval has weird effects, dunno why
          #self.instance_eval &block
          return block.call
        ensure
          FileUtils.cd old_dir
        end
      else
        FileUtils.cd File.expand_path(dir)
      end
    end

    def cmd(method,*args)
      Rubish::Command.new(method,args)
    end

    def p(&block)
      # self is the workspace
      Rubish::Pipe.new(self,&block)
    end

    def exec(*exes)
      __exec(:exec,exes)
    end

    def exec!(*exes)
      __exec(:exec!,exes)
    end

    private

    def __exec(exec_method,exes)
      exes.map do |exe|
        raise "not an exeuctable: #{exe}" unless exe.is_a?(Rubish::Executable)
        exe.send(exec_method)
      end
    end
    
  end

  include Base

  attr_accessor :command_factory_hook
  def initialize
    # @vars = {}
    # this is a hack for pipe... dunno if there's a better way to do it.
    @command_factory_hook = nil
  end

  def extend(*modules)
    modules.each do |m|
      self.__extend(m)
    end
  end

  def eval(__string=nil,&__block)
    raise "should be either a string or a block" if __string && __block
    if __block
      self.__instance_eval(&__block) 
    else
      self.__instance_eval(__string)
    end
  end

  def method_missing(method,*args,&block)
    cmd = Rubish::Command.new(method,args)
    if @command_factory_hook.is_a?(Proc)
      @command_factory_hook.call(cmd)
    else
      cmd
    end
  end

  def inspect
    self.__inspect
  end
  
end
