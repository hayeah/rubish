# this implements the streaming abstraction for
# Rubish::{Sed,Awk}, corresponding to Unix
# Power Fools of similar names.
module Rubish::Streamer
  attr_accessor :line
  attr_reader :output
  attr_reader :lineno
  attr_reader :buckets, :bucket_types
  
  def init_streamer
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

  def pp(obj)
    output.pp obj
  end

  ##################################################
  # Line Buffer Handling Stuff

  def process_stream(stream,output)
    raise "should init streamer with an IO object" unless stream.is_a?(IO)
    @output = output
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

  def act(address=nil,&block)
    raise "addressed action not implemented yet" if address
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
    create_bucket(:collect,name,nil)
    update_bucket(name,val,key) do |acc,val|
      if acc.nil?
        acc = [val]
      else
        acc << val
      end
    end
  end

  private

  # [type] denotes an aggregate of type
  # type denotes the type itself (non-aggregate)
  def create_bucket(type,name,init_val)
    name = name.to_s
    if buckets.has_key?(name)
      raise "conflict bucket types for: #{name}" unless bucket_types[name] == type
      return false
    else
      raise "bucket name conflicts with existing method: #{name}" if self.respond_to?(name)
      bucket_types[name] = type
      buckets[name] = Hash.new(init_val)
      #singleton = class << self; self; end

      defstr = <<-HERE
def #{name}(key=nil)
  buckets["#{name}"][key]
end
HERE
      self.instance_eval(defstr)


    end
    return true
  end
  
  def update_bucket(name,val,key=nil)
    name = name.to_s
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
