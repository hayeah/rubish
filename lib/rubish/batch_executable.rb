# wraps all the processing in a context with a job
# (which encapsulates a thread).
class Rubish::BatchExecutable < Rubish::Executable
  

  def initialize(context,&block)
    @context = context
    @proc = block
  end
  
  def exec!
    ctxt = @context.derive(nil,self.i,self.o,self.err)
    # this block will execute in a thread
    Rubish::Job::ThreadJob.new {
      begin
        ctxt.eval &@proc
      ensure
        ctxt.job_control.waitall
      end
    }
  end

  def exec
    exec!.wait
  end
  
end
