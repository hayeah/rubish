
# a job is not necessarily registered with job control.
class Rubish::Job

  attr_accessor :result

  # subclass initializer MUST call super
  def initialize(*args)
    @result = nil
    @done = false
  end

  def stop
    raise "abstract"
  end

  # must set @done to true after wait
  def wait
    raise "abstract"
  end

  def done?
    raise "job subclass implementation error" if @done.nil?
    @done
  end
  
end
