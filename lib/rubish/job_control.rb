# TODO extend this for bg/fg (maybe?)
# Assume that job control is used by a single thread...

require 'thread'
class Rubish::JobControl

  class << self
    def current
      Rubish::Context.current.job_control
    end
  end

  def initialize
    @mutex = Mutex.new
    @jobs = {}
  end

  def jobs
    @jobs.values
  end

  def submit(job)
    raise "expects a Rubish::JobControl::Job" unless job.is_a?(Rubish::Job)
    @mutex.synchronize {
      @jobs[job.object_id] = job
    }
  end

  def remove(job)
    raise "expects a Rubish::JobControl::Job" unless job.is_a?(Rubish::Job)
    raise Rubish::Error.new("Job not found: #{job}") unless @jobs.include?(job.object_id)
    @mutex.synchronize {
      @jobs.delete(job.object_id)
    }
  end

  def wait(*jobs)
    rss = jobs.map do |job|
      job.wait
      if block_given?
        yield(job)
      else
        job
      end
    end
    return *rss
  end

  # TODO handle interrupt
  def waitall(&block)
    wait(*@jobs.values,&block)
  end
  
  
end


