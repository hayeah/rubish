class Rubish::UnixExecutable < Rubish::Executable
  EIO = Rubish::Executable::ExecutableIO
  class UnixJob < Rubish::Job
    attr_reader :pids

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
      @result = self.pids.map do |pid|
        Process.wait(pid)
        $?
      end
      @ios.each do |io|
        io.close
      end
      __finish
      return self
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

    def ok?
      done? && !@result.any? {|status| !(status.exitstatus == 0)}
    end

  end

  def exec!
    UnixJob.new(self)
  end

  # TODO catch interrupt here
  def exec
    exec!.wait
  end

end
