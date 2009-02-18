
class Rubish::Pipe < Rubish::Executable
  attr_reader :cmds
  def initialize(&block)
    super
    @cmds = []
    if block
      mu = Rubish::Mu.new &(self.method(:mu_handler).to_proc)
      mu.__instance_eval(&block)
    end
    # dun wanna handle special case for now
    raise "pipe length less than 2" if @cmds.length < 2
  end

  def mu_handler(m,args,block)
    # block's not actually used
    raise "command builder doesn't take a block" unless block.nil?
    if m == :ruby
      raise "not supported yet"
      @cmds << [args,block]
    else
      @cmds << Rubish::Command::ShellCommand.new(m,args)
    end
  end

  def exec_
    # pipes == [i0,o1,i1,o2,i2...in,o0]
    # i0 == $stdin
    # o0 == $stdout
    pipe = nil # [r, w]
    pids = []
    @cmds.each_index do |index|
      if index == 0 # head
        i = io_in
        pipe = IO.pipe
        o = pipe[1] # w
      elsif index == (@cmds.length - 1) # tail
        i = pipe[0]
        o = io_out
      else # middle
        i = pipe[0] # r
        pipe = IO.pipe
        o = pipe[1]
      end

      cmd = @cmds[index]
      if child = fork # children
        #parent
        pids << child
        i.close unless i == io_in
        o.close unless o == io_out
      else
        $stdin.reopen(i)
        $stdout.reopen(o)
        Kernel.exec cmd.cmd
      end
    end
    return pids
  end

  def exec
    self.exec_
    ps = Process.waitall
  end

  def each_
    r,w = IO.pipe
    begin
      self.o(w)
      self.exec_
      w.close
      r.each_line do |l|
        yield(l)
      end
    ensure
      r.close
    end
    return nil
  end

  def each
    self.each_ do |l|
      Rubish.session.submit(yield(l))
    end
  end

  def map
    acc = []
    self.each_ do |l|
      acc << (block_given? ? yield(l) : l )
    end
    acc
  end
  
end
