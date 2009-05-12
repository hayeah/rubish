
# A job is not necessarily registered with job
# control.

# TODO extend this for bg/fg (maybe?)
# Assume that job control is used by a single thread...

require 'thread'
class Rubish::JobControl
  
  attr_reader :jobs

  def initialize
    @mutex = Mutex.new
    @jobs = { }
  end

  # need to synchronize access to the jobs hash
  def submit(job)
    raise "expects a Rubish::JobControl::Job" unless job.is_a?(Rubish::Job)
    mutex.synchronize {
      jobs[job.object_id] = job
    }
  end

  def remove(job)
    mutex.synchronize {
      jobs.delete(job.object_id)
    }
  end

  def wait(*jobs)
    rss = jobs.map do |job|
      # we might already have waited for this job.
      job.wait if job.active?
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
    wait(*jobs.values,&block)
  end
  
  
end


