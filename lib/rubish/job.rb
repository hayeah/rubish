
# a job is not necessarily registered with job control.
class Rubish::Job

  attr_accessor :result
  
  def initialize
    @result = nil
  end

  def stop
    raise "abstract"
  end

  # must set result to non-nil after wait
  def wait
    raise "abstract"
  end

  def active?
    result.nil?
  end
  
end
