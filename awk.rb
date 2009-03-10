# awkish wrapper to Rubish::Executable types to
# produce ruby values
class Rubish::Awk < Rubish::Evaluable
  include Rubish::Streamer
  
  class << self
    def make(exe,fs=nil,&block)
      a = Rubish::Awk.new(exe)
      if fs
        a.fs(fs)
      end
      if block
        a.act(&block)
      end
      a
    end
  end
    
  attr_reader :a # array of fields
  attr_reader :r # string of current record
  attr_reader :nf # number of fields for current record
  attr_reader :buckets, :bucket_types
  
  def initialize(exe)
    init_streamer
    @exe = exe
    @fs = /\s+/
    @nf = 0 # number of fields for a record
    @acts = []
    @beg_act  = nil
    @end_act = nil
    @buckets = {}
    @bucket_types = {}
  end
  
  def rs=(*args)
    raise "record separator not supported"
    self
  end

  def fs(fs)
    @fs = fs
    self
  end

  def nr
    lineno
  end

  def stream_begin
    self.instance_eval(&@beg_act) if @beg_act
  end

  def init_line
    @a = line.split(@fs)
    @nf = @a.length
    @r = line
  end

  def stream_end
    self.instance_eval(&@end_act) if @end_act
  end

  def eval
    result = nil
    @exe.pipe_out do |pipe|
      result = process_stream(pipe,$stdout)
    end
    return result
  end
  
  def begin(&block)
    @beg_act = block
    self
  end

  def end(&block)
    @end_act = block
    self
  end

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
