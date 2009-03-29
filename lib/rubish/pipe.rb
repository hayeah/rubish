
class Rubish::Pipe < Rubish::Executable
  attr_reader :cmds
  def initialize(&block)
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
    if m == :rb
      raise "not supported yet"
      @cmds << [args,block]
    else
      cmd = Rubish::Command.new(m,args)
      @cmds << cmd
      return cmd
    end
  end

  def exec_with(pipe_in,pipe_out,pipe_err)
    @cmds.each do |cmd|
      if cmd.i || cmd.o || cmd.err
        raise "It's weird to redirect stdioe for command in a pipeline. Don't."
      end
    end
    # pipes == [i0,o1,i1,o2,i2...in,o0]
    # i0 == $stdin
    # o0 == $stdout
    pipe = nil # [r, w]
    pids = []
    @cmds.each_index do |index|
      tail = index == (@cmds.length - 1) # tail
      head = index == 0 # head
      if head
        i = pipe_in
        pipe = IO.pipe
        o = pipe[1] # w
      elsif tail
        i = pipe[0]
        o = pipe_out
      else # middle
        i = pipe[0] # r
        pipe = IO.pipe
        o = pipe[1]
      end

      cmd = @cmds[index]
      if child = fork # children
        #parent
        pids << child
        # it's important to close the pipes held
        # by spawning parent, otherwise the pipes
        # would not close after a program ends.
        i.close unless head
        o.close unless tail
      else
        # Rubish.set_stdioe((cmd.i || i),(cmd.o || o),(cmd.err || pipe_err))
        cmd.system_exec(i,o,pipe_err)
      end
    end
    return pids
  end
  
end
