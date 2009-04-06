class Rubish::Job
  attr_reader :pids
  attr_accessor :exit_statuses
  attr_reader :ticket
  
  def initialize(pids)
    @@ticket ||= 0
    @@ticket += 1
    @ticket = @@ticket
    @pids = pids
    @exit_statuses = nil # JobControl will set this field in #wait
    # add job to the job_control of the active session
    Rubish::Session.job_control.started(self)
  end

  def ok?
    not exit_statuses.any? {  |status| !(status.exitstatus == 0) }
  end
  
end
