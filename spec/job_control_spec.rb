require 'spec_helper'

describe "Job Control" do
  include Helpers::Commands

  let(:job_control) { Rubish::Context.current.job_control }

  def jobs
    job_control.jobs
  end

  def start_jobs
    @cmd = slow(100)
    @job1 = @cmd.exec!
    @job2 = @cmd.exec!
  end
  
  context "tracker" do
    before { start_jobs }
    
    after { job_control.waitall }

    it "has two job" do
      jobs.size.should == 2
    end

    it "includes job 1" do
      jobs.should include(@job1)
    end

    it "includes job 2" do
      jobs.should include(@job2)
    end
  end

  context "#waitall" do
    before {
      start_jobs
      @time = elapsed { job_control.waitall }
    }

    it "does the jobs concurrently" do
      @time.should be_within(50).of(100)
    end

    it "returns after jobs are completed" do
      @job1.should be_done
      @job2.should be_done
    end
  end
  
end
