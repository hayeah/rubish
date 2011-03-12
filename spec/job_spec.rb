require 'spec_helper'

describe Rubish::Job do
  include Helpers::Commands

  def elapsed
    t1 = Time.now
    yield
    return (Time.now - t1) * 1000
  end
  
  context "running command in background" do
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
end
