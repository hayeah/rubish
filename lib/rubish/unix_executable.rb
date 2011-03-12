class Rubish::UnixExecutable < Rubish::Executable
  EIO = Rubish::Executable::ExecutableIO
  
  class UnixJob < Rubish::Job
    attr_reader :pids
    attr_reader :goods
    attr_reader :bads
    attr_reader :statuses

    class BadExit < RuntimeError
      attr_reader :exitstatuses
      def initialize(exitstatuses)
        @exitstatuses = exitstatuses
      end
    end

    def initialize(exe)
      # prepare_io returns an instance of ExeIO
      @ios = EIO.ios([exe.i || Rubish::Context.current.i,"r"],
                     [exe.o || Rubish::Context.current.o,"w"],
                     [exe.err || Rubish::Context.current.err,"w"])
      i,o,err = @ios
      @pids = exe.exec_with(i.io,o.io,err.io)
      __start
    end

    def wait
      raise Rubish::Error.new("already waited") if self.done?
      begin
        wait_children_processes
        @result = success?
      ensure
        __finish
      end
    end

    def stop(sig="TERM")
      self.pids.each do |pid|
        Process.kill(sig,pid)
      end
      self.wait
    end

    def stop!
      self.stop("KILL")
    end

    def success?
      bads.empty?
    end

    private

    def wait_children_processes
      @statuses = self.pids.map do |pid|
        Process.wait(pid)
        $?
      end
      
      @ios.each do |io|
        io.close
      end

      @goods, @bads = @statuses.partition { |status| status.exitstatus == 0}
    end
  end

  def exec!
    UnixJob.new(self)
  end

  # TODO catch interrupt here
  def exec
    exec!.wait
  end

  def exec_with(i,o,e)
    raise "abstract"
  end
end
