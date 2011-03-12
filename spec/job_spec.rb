require 'spec_helper'

describe Rubish::Job do
  include Helpers::Commands

  def elapsed
    t1 = Time.now
    yield
    return (Time.now - t1) * 1000
  end
  
  context "running a job in background" do
    before {
      @time1 = elapsed {
        @job = slow(100).exec!
      }

      @time2 = elapsed {
        @status = @job.wait
      }
    }

    it "has an associated job" do
      @job.should be_a(Rubish::Job)
    end

    it "is done" do
      @job.should be_done
    end

    it "succeeded" do
      @job.should be_success
    end

    it "executes in background" do
      @time1.should < 100
    end

    it "waits for process to coplete" do
      @time2.should > 100
    end
  end

  context "killing a job" do
    before {
      @job = slow(1000).exec!
      # give the forked process time to execute
      # the command, otherwise the child process
      # would still be in RSpec
      sleep(0.1)
      @job.kill
    }

    it "is done" do
      @job.should be_done
    end

    it "did not succeed" do
      @job.should_not be_success
    end

    it "caused the process to exit with a signal" do
      status = @job.bads.first
      status.should be_a(Process::Status)
      status.should be_signaled
      status.termsig.should == 15
    end
  end
end
