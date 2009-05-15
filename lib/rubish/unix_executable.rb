class Rubish::UnixExecutable < Rubish::Executable
  EIO = Rubish::Executable::ExecutableIO
  
  class UnixJob < Rubish::Job
    attr_reader :pids
    attr_reader :goods
    attr_reader :bads

    class BadExit < RuntimeError
      attr_reader :exitstatuses
      def initialize(exitstatuses)
        @exitstatuses = exitstatuses
      end
    end

    def initialize(exe)
      # prepare_io returns an instance of ExeIO
      i = EIO.i(exe.i)
      o = EIO.o(exe.o)
      e = EIO.err(exe.err)
      @ios = [i,o,e]
      @pids = exe.exec_with(i.io,o.io,e.io)
      __start
    end

    def wait
      raise Rubish::Error.new("already waited") if self.done?
      begin
        exits = self.pids.map do |pid|
          Process.wait(pid)
          $?
        end
        @ios.each do |io|
          io.close
        end
        @goods, @bads = exits.partition { |status| status.exitstatus == 0}
        @result = goods # set result to processes that exit properly
        if !bads.empty?
          raise Rubish::Job::Failure.new(self,BadExit.new(bads))
        else
          return self
        end
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
