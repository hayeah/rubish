# awkish wrapper to Rubish::Executable types to
# produce ruby values
class Rubish::Awk < Rubish::Evaluable
  
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
  attr_reader :nr # number of records so far
  attr_reader :nf # number of fields for current record
  attr_reader :buckets, :bucket_types
  
  def initialize(exe)
    @exe = exe
    @fs = /\s+/
    @nr = 0 # number of records matched
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
  
  def eval
    self.instance_eval(&@beg_act) if @beg_act
    @exe.each_ do |record|
      @nr += 1
      @a = record.split(@fs)
      @nf = @a.length
      @r = record

      self.instance_eval(&@act)
    end

    return self.instance_eval(&@end_act) if @end_act
  end
  
  # one clause is enough
  def act(&block)
    @act = block
    self
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

  def pick(name,*args)
    create_bucket(:pick,name,nil)
    update_bucket(name,args) do |old_v,new_v|
      if old_v.nil?
        new_v
      else
        yield(old_v,new_v)
      end
    end
  end
  
  def max(name,*args)
    create_bucket(:max,name,nil)
    update_bucket(name,args) do |old,new|
      if old.nil?
        new
      elsif new > old
        new
      else
        old
      end
    end
  end

  def min(name,*args)
    create_bucket(:min,name,nil)
    update_bucket(name,args) do |old,new|
      if old.nil?
        new
      elsif new < old
        new
      else
        old
      end
    end
  end

  def collect(name,*args)
    create_bucket(:collect,name,nil)
    update_bucket(name,args) do |acc,val|
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
  
  def update_bucket(name,args)
    name = name.to_s
    if args.length == 1
      key = nil
      val = args.first
    elsif args.length == 2
      key, val = args
    end
    new_val = yield(buckets[name][key],val)
    buckets[name][key] = new_val
  end
  
end
