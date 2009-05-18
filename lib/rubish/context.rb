class Rubish::Context

  class << self
    def singleton
      @singleton ||= self.new(Rubish::Workspace.global,
                              $stdin,$stdout,$stderr)
    end
    alias_method :global, :singleton
    
    def current
      Thread.current["rubish.context"] || self.singleton
    end

    def as_current(context,&block)
      raise "expects a context" unless context.is_a?(Rubish::Context)
      begin
        old_context = Thread.current["rubish.context"]
        Thread.current["rubish.context"] = context
        block.call
      ensure
        Thread.current["rubish.context"] = old_context
      end
    end
  end

  attr_accessor :i, :o, :err
  attr_accessor :workspace
  attr_reader :pwd # working_directory
  attr_reader :job_control
  attr_reader :parent
  
  # prototype style cloning, but only on select attributes
  def initialize(workspace,i=nil,o=nil,err=nil)
    # a cloned context inherits the follow attributes
    @workspace = workspace
    @i = i || Rubish::Context.current.i
    @o = o || Rubish::Context.current.o
    @err = err || Rubish::Context.current.err
    # @pwd = Dir.pwd

    # not these
    @job_control = Rubish::JobControl.new
    @parent = nil
  end

  def initialize_copy(from)
    # note that we use the cloned workspace of the parent's workspace.
    initialize(from.workspace.derive,
               from.i, from.o, from.err)
    @job_control = Rubish::JobControl.new
  end

  def derive(workspace=nil,i=nil,o=nil,err=nil)
    parent = self
    child = parent.clone
    child.instance_eval {
      @parent = parent
      @workspace = workspace if workspace
      @i = i if i
      @o = o if o
      @err = err if err
    }
    return child
  end
  
  def eval(string=nil,&block)
    Rubish::Context.as_current(self) {
      if string
        self.workspace.eval(string)
      else
        eslf.workspace.eval(&block)
      end
    }
  end
end
