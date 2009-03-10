class Rubish::Sed < Rubish::Executable

  attr_accessor :this
  attr_reader :o
  def initialize(exe)
    @acts = []
    @exe = exe
    @no_print = false
    @quit = false
    @buffer = [] # look ahead buffer for peek(n)
    @this = nil # the current line ("pattern space" in sed speak)
    @interrupt = nil # a few methods could interrupt the sed process loop.
  end

  def exec_with(_i,o,_e)
    @o = o # i think only the output IO parameter makes sense.
    @exe.pipe_out do |pipe|
      @pipe = pipe
      while string = get_string
        @this = string
        interrupted = true
        catch :interrupt do
          @acts.each do |act|
            return if @quit
            self.instance_eval(&act)
          end
          interrupted = false
        end
        if interrupted
          case @interrupt
          when :quit
            return # from sed
          when :next
            next # restart loop, skip other actions
          else
            raise "Unknown Sed Interrupt: #{@interrupt}"
          end
        end
      end
    end
  end

  def act(&block)
    @acts << block
    return self
  end

  def interrupt(cmd=nil)
    @interrupt = cmd
    throw :interrupt
  end

  # returns line and advances the cursor.
  # nil if EOF.
  def get_string
    # use line in lookahead buffer if there's any
    if @buffer.empty?
      r = @pipe.gets
      r.chomp! if r
      return r
    else
      @buffer.shift
    end
  end

  # peek(n) returns n (or less, if we reach EOF)
  # lines from the cursor without advancing it.
  def peek(n=1)
    lines = @buffer[0...n]
    # return if we have enough lines in buffer to satisfy peek.
    return lines if lines.length == n
    # or keep reading from the pipe if we don't.
    n = n - lines.length
    n.times do |i|
      s = @pipe.gets
      break if s.nil? # EOF
      s.chomp!
      lines << s
      @buffer << s
    end
    return lines
  end

  # advances cursor by n
  # returns false if EOF
  # returns true otherwise.
  def skip(n=1)
    n.times do
      return false unless get_line
    end
    return !peek.nil?
  end

  # skip other actions
  def next
    interrupt(:next)
  end

  def quit
    interrupt(:quit)
  end

  def q
    self.quit
  end

  def s(regexp,sub)
    @this.sub!(regexp,sub)
    return @this
  end

  def gs(regexp,sub)
    @this.gsub!(regexp,sub)
    return @this
  end

  def p(string=nil)
    self.o.puts(@this || string)
  end
  

  
  
end
