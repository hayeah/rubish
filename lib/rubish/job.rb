
# a job is not necessarily registered with job control.
class Rubish::Job

  attr_accessor :result
  attr_reader :job_control

  # subclass initializer MUST call __start
  def initialize(*args)
    raise "abstract"
    __start
  end

  def __start
    @result = nil
    @done = false
    # when wait is called, the job control may or
    # may not be the current job_control.
    @job_control = Rubish::JobControl.current 
    @job_control.submit(self)
    self
  end

  def __finish
    @job_control.remove(self)
    @done = true
    self
  end

  # MUST call __finish after wait
  def wait
    raise "abstract"
    __finish
  end

  # MUST result in calling __finish
  def stop
    raise "abstract"
  end

  def done?
    @done
  end
  
end
