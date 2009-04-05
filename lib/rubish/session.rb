# There should be only one active session per rubish process
# Session controls over a number of workspaces (which are just evaluation contexts)
# Session has a single job_control over all the workspaces.
class Rubish::Session

  module JobControl
    def wait(*jobs)
      job_control.wait(*jobs)
    end

    def waitall
      job_control.waitall
    end

    def stop(job)
      job_control.stop(job)
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

  include JobControl
  
  class << self

    include JobControl

    def new_session
      @session.exit if @session
      @session = Rubish::Session.new
    end

    def session(&block)
      raise "no active session" unless @session
      if block
        @session.instance_eval &block
      else
        @session
      end
    end

    def repl
      self.new_session.repl
    end

    def eval(__string=nil,&block)
      self.new_session.current_workspace.eval(__string,&block)
    end
  end

  attr_reader :job_control
  attr_reader :root_workspace
  attr_reader :current_workspace
  
  def initialize
    @scanner = RubyLex.new
    @job_control = Rubish::JobControl.new
    @root_workspace = Rubish::Workspace.new
    @current_workspace = @root_workspace
  end

  def repl(workspace=@root_workspace)
    raise "$stdin is not a tty device" unless $stdin.tty?
    raise "readline is not available??" unless defined?(IRB::ReadlineInputMethod)
    rl = IRB::ReadlineInputMethod.new

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
      rl.prompt = p
    end
    
    @scanner.set_input(rl)

    @scanner.each_top_level_statement do |line,line_no|
      begin
        r = workspace.eval(line)
        if r.is_a?(Rubish::Executable)
          r.exec
          #     elsif r.is_a?(Rubish::Evaluable)
        elsif r != Rubish::Null
          pp r
        end
      rescue StandardError, ScriptError => e
        puts e
        puts e.backtrace
      end
    end
  end

  def exit
    waitall
  end
    
end
