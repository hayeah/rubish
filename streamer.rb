# this implements the streaming abstraction for
# Rubish::{Sed,Awk}, corresponding to Unix
# Power Fools of similar names.
module Rubish::Streamer
  attr_accessor :line
  attr_reader :lineno
  
  def init_streamer
    @acts = []
    @buffer = [] # look ahead buffer for peek(n)
    @line = nil # the current line ("pattern space" in sed speak)
    @lineno = 0 # current line number
    @interrupt = nil # a few methods could interrupt the sed process loop.
  end

  def process_stream(stream)
    raise "should init streamer with an IO object" unless stream.is_a?(IO)
    @stream = stream
    begin
      stream_begin # abstract
      while string = get_string
        @line = string
        init_line # abstract
        interrupted = true
        catch :interrupt do
          @acts.each do |act|
            # evaluate in the context of the object that included the Streamer.
            self.instance_eval(&act)
          end
          interrupted = false
        end
        if interrupted
          case @interrupt
          when :quit
            break # stop processing
          when :next
            next # restart loop, skip other actions
          else
            raise "Unknown Sed Interrupt: #{@interrupt}"
          end
        end
      end
    ensure
      stream_end # abstract
    end
  end

  def stream_begin
    raise "abstract"
  end

  def init_line
    raise "abstract"
  end

  def stream_end
    raise "abstract"
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
      r = @stream.gets
      r.chomp! if r
    else
      r = @buffer.shift
    end
    @lineno += 1 if r # increments lineno iff it's not EOF
    return r
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
      s = @stream.gets
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
  
end
