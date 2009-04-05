
class Rubish::Session

  class << self
    def session(&block)
      raise "no session" unless @session
      if block
        @session.instance_eval &block
      else
        @session
      end
    end

    # TODO: uhhh... bad abstraction. remove this when i
    # figure out something better
    def begin(&block)
      begin
        s = Rubish::Session.new
        @session = s
        r = s.begin &block
        s.waitall
        return r
      ensure
        @session = nil
      end
    end

    def repl
      begin
        @session = Rubish::Session.new
        @session.repl
      end
    end
  end

  module JobControl
    def wait(*jobs)
      job_control.wait(*jobs)
    end

    def waitall
      job_control.waitall
    end

    def kill(job)
      job_control.kill(job)
    end

    def jobs
      job_control.jobs
    end

    def job_control
      Rubish::Session.session.job_control
    end

    private

    def job_started(job)
      job_control.started(job)
    end
  end

  module Base
    include JobControl
    
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
      Rubish::Pipe.new &block
    end

#     def awk
#       Rubish::Awk.new
#     end
  end

  include Base
  attr_reader :job_control

  def initialize
    @vars = {}
    @scanner = RubyLex.new
    @job_control = Rubish::JobControl.new
  end

  def repl
    raise "$stdin is not a tty device" unless $stdin.tty?
    raise "readline is not available??" unless defined?(IRB::ReadlineInputMethod)
    __rl = IRB::ReadlineInputMethod.new

    @scanner.set_prompt do |ltype, indent, continue, line_no|
      # ltype is Delimiter type. In strings that are continued across a line break, %l will display the type of delimiter used to begin the string, so you'll know how to end it. The delimiter will be one of ", ', /, ], or `.
      if ltype or indent > 0 or continue
        p = ". "
      else
        p = "> "
      end
      if indent
        p << " " * indent
      end
      __rl.prompt = p
    end
    
    @scanner.set_input(__rl)

    # create the evaluative context
    # TODO abstract this as workspace?
    __mu = Rubish::Mu.new(Base) do |method,args,block|
      Rubish::Command.new(method,args)
    end
    
    @scanner.each_top_level_statement do |__line,__line_no|
      begin
        # don't ever try to do anything with mu except Mu#__instance_eval
        __r = __mu.__instance_eval(__line)
        self.submit(__r)
      rescue StandardError, ScriptError => __e
        puts __e
        puts __e.backtrace
      end
    end
  end


  module ScriptBase
    include Base

    def exec(*exes)
      __exec(:exec,exes)
    end

    def exec!(*exes)
      __exec(:exec!,exes)
    end

    private

    def __exec(exec_method,exes)
      exes.each do |exe|
        raise "not an exeuctable: #{exe}" unless exe.is_a?(Rubish::Executable)
        exe.send(exec_method)
      end
    end
  end
  
  def begin(&block)
    Rubish::Mu.new(ScriptBase) do |method,args,block|
      Rubish::Command.new(method,args)
    end.__instance_eval &block
  end

  def submit(r)
    if r.is_a?(Rubish::Executable)
      r.exec
#     elsif r.is_a?(Rubish::Evaluable)
#       submit(r.eval)
    elsif r != Rubish::Null
      pp r
    end
  end
  
end