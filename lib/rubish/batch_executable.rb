# wraps all the processing in a context with a job
# (which encapsulates a thread).
class Rubish::BatchExecutable < Rubish::Executable
  class BatchJob < Rubish::Job
    attr_reader :thread
    def initialize(&block)
      # run block in a thread
      @thread = Thread.new {
        block.call
      }
      __start
    end

    def wait
      # wait thread to complete
      begin
        @thread.join
        @result = @thread.value
        return self
      rescue => e
        raise Rubish::Job::Failure.new(self,e)
      ensure
        __finish
      end
    end

    def stop
      @thread.kill
      wait
    end
    
  end

  def initialize(context,&block)
    @context = context
    @proc = block
  end
  
  def exec!
    ctxt = @context.derive(nil,self.i,self.o,self.err)
    # this block will execute in a thread
    BatchJob.new {
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
