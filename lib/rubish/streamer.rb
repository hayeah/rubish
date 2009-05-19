# a Streamer wraps the output of an exectuable
#
# this implements the streaming abstraction for
# Rubish::{Sed,Awk}, corresponding to Unix
# Power Fools of similar names.
class Rubish::Streamer < Rubish::Executable

  class Trigger
    attr_accessor :inverted
    def initialize(streamer,block,a,b,inverted=false)
      @block = block
      @streamer = streamer
      raise "the first pattern can't be null" if a.nil?
      @a = a
      @b = b # could be nil. If so, this is a positioned trigger.
      @inverted = inverted
      @tripped = false
    end

    def call
      if @b
        @streamer.instance_eval(&@block) if range_trigger
      else
        @streamer.instance_eval(&@block) if position_trigger
      end
    end

    def range_trigger
      if @tripped
        @tripped = !test(@b)
        true
      else
        @tripped = test(@a)
      end
    end

    def position_trigger
      test(@a)
    end

    def test(trigger)
      case trigger
      when :eof, -1
        @streamer.peek.empty?
      when :bof, 1
        @streamer.lineno == 1
      when Integer
        @streamer.lineno == trigger
      when Regexp
        !(@streamer.line =~ trigger).nil?
      end
    end
  end
  attr_accessor :line
  attr_reader :output
  attr_reader :lineno
  attr_reader :buckets, :bucket_types
  attr_reader :exe
  
  def initialize(exe)
    @exe = exe
    @acts = []
    @output = nil # the IO object that puts and pp should write to.
    @buffer = [] # look ahead buffer for peek(n)
    @line = nil # the current line ("pattern space" in sed speak)
    @lineno = 0 # current line number
    @interrupt = nil # a few methods could interrupt the sed process loop.
    @buckets = {}
    @bucket_types = {}
  end

  def puts(*args)
    output.puts args
  end

  # redirect
  def exec!
    streamer = self
    Rubish::Job::ThreadJob.new {
      begin
        result = nil
        old_output = streamer.exe.o
        output = Rubish::Executable::ExecutableIO.ios([streamer.o || Rubish::Context.current.o,"w"]).first
        # ask exe to output to a pipe
        streamer.exe.o { |input|
          # input to streamer is the output of the executable
          result = streamer.exec_with(input,output.io,nil)
        }.exec
        result
      ensure
        streamer.exe.o = old_output # restores the output of the old executable
        output.close if output
      end
    }
  end

  def exec
    exec!.wait
  end

  def pp(obj)
    output.pp obj
  end

  ##################################################
  # Line Buffer Handling Stuff

  def exec_with(i,o,_e=nil)
    raise "error stream shouldn't be used" if _e
    @output = o
    @input = i
    begin
      stream_begin # abstract
      while string = get_string
        @line = string
        init_line # abstract
        interrupted = true
        catch :interrupt do
          @acts.each do |act|
            # evaluate in the context of the object that included the Streamer.
            if act.is_a?(Trigger)
              act.call
            else
              self.instance_eval(&act)
            end
          end
          interrupted = false
        end
        if interrupted
          case @interrupt
          when :quit
            break # stop processing
          when :done
            next # restart loop, skip other actions
          else
            raise "Unknown Sed Interrupt: #{@interrupt}"
          end
        end
      end
    ensure
      result = stream_end # abstract
    end
    return result
  end

  def stream_begin
    raise "abstract"
  end

  def init_line
    raise "abstract"
  end

  # the return value of this method is taken to be
  # the return value of process_stream
  def stream_end
    raise "abstract"
  end

  def act(a=nil,b=nil,&block)
    if a || b
      @acts << Trigger.new(self,block,a,b)
    else
      @acts << block
    end
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
      r = @input.gets
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
      s = @input.gets
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
      return false unless get_string
    end
    return !peek.nil?
  end

  # skip other actions
  def done
    interrupt(:done)
  end

  def quit
    interrupt(:quit)
  end

  ##################################################
  # Bucket Handling Stuff

  
  # common-lisp loopesque helpers
  def count(name,key=nil)
    create_bucket(:count,name,0)
    update_bucket(name,[key,nil]) do |old_c,ignore|
      old_c + 1
    end
  end

  def pick(name,val,key=nil)
    create_bucket(:pick,name,nil)
    update_bucket(name,val,key) do |old_v,new_v|
      if old_v.nil?
        new_v
      else
        yield(old_v,new_v)
      end
    end
  end
  
  def max(name,val,key=nil)
    create_bucket(:max,name,nil)
    update_bucket(name,val,key) do |old,new|
      if old.nil?
        new
      elsif new > old
        new
      else
        old
      end
    end
  end

  def min(name,val,key=nil)
    create_bucket(:min,name,nil)
    update_bucket(name,val,key) do |old,new|
      if old.nil?
        new
      elsif new < old
        new
      else
        old
      end
    end
  end

  def collect(name,val,key=nil)
    # the initial value should be nil, if it's the
    # empty array, it would be shared among all
    # the buckets (which is incorrect (since we
    # are doing destructive append))
    create_bucket(:collect,name,nil)
    update_bucket(name,val,key) do |acc,val|
      if acc.nil?
        acc = [val]
      else
        acc << val
      end
      acc
    end
  end

  # size-limited FIFO buffer
  def hold(name,size,val,key=nil)
    raise "hold size should be larger than 1" unless size > 1
    create_bucket(:hold,name,nil)
    update_bucket(name,val,key) do |acc,val|
      if acc.nil?
        acc = [val]
      elsif acc.length < size
        acc << val
      else
        acc.shift
        acc << val
      end
      acc
    end
  end

  private

  # [type] denotes an aggregate of type
  # type denotes the type itself (non-aggregate)
  def create_bucket(type,name,init_val)
    name = name.to_sym
    if buckets.has_key?(name)
      raise "conflict bucket types for: #{name}" unless bucket_types[name] == type
      return false
    else
      raise "bucket name conflicts with existing method: #{name}" if self.respond_to?(name)
      bucket_types[name] = type
      buckets[name] = Hash.new(init_val)
      #singleton = class << self; self; end

      defstr = <<-HERE
def #{name.to_s}(key=nil)
  buckets[:#{name.to_s}][key]
end
HERE
      self.instance_eval(defstr)


    end
    return true
  end
  
  def update_bucket(name,val,key=nil)
    name = name.to_sym
    # if a key is given, update the key specific sub-bucket.
    if key
      new_val = yield(buckets[name][key],val)
      buckets[name][key] = new_val
    end
    # always update the special nil key.
    new_val = yield(buckets[name][nil],val)
    buckets[name][nil] = new_val
  end

  
end
