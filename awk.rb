# awkish extension to Rubish::Command

class Rubish::Awk < Rubish::Executable
  
  # internal
  
#   attr_reader :beg_act
#   attr_reader :acts
#   attr_reader :end_act

  attr_reader :a # array of fields
  attr_reader :r # string of current record
  attr_reader :nr # number of records so far
  attr_reader :nf # number of fields for current record
  
  def initialize(cmd)
    @cmd = cmd
    @fs = /\s+/
    @nr = 0 # number of records matched
    @nf = 0 # number of fields for a record
    @acts = []
    @beg_act  = nil
    @end_act = nil
  end
  
  def rs=(*args)
    raise "record separator not supported"
    self
  end

  def fs=(fs)
    @fs = fs
    self
  end
  
  def exec
    self.instance_eval(&@beg_act) if @beg_act
    @cmd.each_ do |record|
      @nr += 1
      @a = record.split(@fs)
      @nf = @a.length
      @r = record
      
      awk = self
      @acts.each do |action|
        # let action be able to access the instance variables in awk
        awk.instance_eval(&action)
      end
    end
    
    return self.instance_eval(&@end_act)  if @end_act
  end

  # an action that returns nil is a null action
  def act(&block)
    @acts << block
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
  def count(bucket_name,&pattern_block)
    ivar = "@#{bucket_name}"
    create_bucket(bucket_name,0)
    self.act do
      if self.instance_eval(&pattern_block)
        count = self.instance_variable_get(ivar)
        self.instance_variable_set(ivar,count+1)
      end
    end
    self
  end

  def collect(bucket_name,&pattern_block)
    ivar = "@#{bucket_name}"
    create_bucket(bucket_name,[])
    self.act do
      if val = self.instance_eval(&pattern_block)
        vals = self.instance_variable_get(ivar)
        vals << val
        self.instance_variable_set(ivar,vals)
      end
    end
    self
  end

  private

  def create_bucket(bucket_name,val)
    ivar = "@#{bucket_name}"
    raise "ivar name already in use: #{bucket_name}" if self.instance_variable_defined?(ivar)
    self.instance_variable_set(ivar,val)
    # attr_reader
    singleton = class << self; self; end
    singleton.send(:define_method,bucket_name) do
      self.instance_variable_get(ivar)
    end
  end
  
end
