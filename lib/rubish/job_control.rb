
# TODO extend this for bg/fg (maybe?)
# Assume that job control is used by a single thread...
class Rubish::JobControl
  
  class Job
    attr_reader :pids
    attr_accessor :exit_statuses
    attr_reader :ticket
    
    def initialize(pids)
      @@ticket ||= 0
      @@ticket += 1
      @ticket = @@ticket
      @pids = pids
      @exit_statuses = nil # JobControl will set this field in #wait
    end

    def ok?
      not exit_statuses.any? {  |status| !(status.exitstatus == 0) }
    end
    
  end

  attr_reader :jobs
  def initialize
    @jobs = { }
    @ticket ||= 0
  end

  def started(job)
    raise "expects a Rubish::JobControl::Job" unless job.is_a?(Job)
    jobs[job.ticket] = job
  end

  def wait(*jobs)
    rss = jobs.map do |job|
      statuses = job.pids.map do |pid|
        Process.wait(pid)
        $?
      end
      job.exit_statuses = statuses
      remove(job)
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

  def stop(job,sig="TERM")
    job.pids.each do |pid|
      Process.kill(sig,pid)
    end
    wait(job)
  end

  def stop!(job)
    stop(job,"KILL")
  end

  private
  
  def remove(job)
    jobs.delete(job.ticket)
  end
  
end


