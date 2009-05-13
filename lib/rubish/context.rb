class Rubish::Context

  class << self
    def singleton
      @singleton ||= self.new(Rubish::Workspace.global,
                              $stdin,$stdout,$stderr)
    end
    
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

  attr_accessor :i, :o, :e
  attr_accessor :workspace
  attr_reader :pwd # working_directory
  attr_reader :job_control
  
  
  def initialize(workspace,i=nil,o=nil,e=nil)
    @workspace = workspace
    @i = i || Rubish::Context.current.i
    @o = o || Rubish::Context.current.o
    @e = e || Rubish::Context.current.e
    # @pwd = Dir.pwd
    @job_control = Rubish::JobControl.new
  end

  def with(workspace)
    raise Rubish::Error.new("expects a workspace") unless workspace.is_a?(Rubish::Workspace)
    @workspace = workspace
    self
  end
  
  def for(&block)
    Rubish::Context.as_current(self) {
      self.workspace.eval &block
    }
    # self.job_control.waitall
  end
end
