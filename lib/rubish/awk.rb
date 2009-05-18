class Rubish::Awk < Rubish::Streamer
  
  attr_reader :a # array of fields
  attr_reader :r # string of current record
  attr_reader :nf # number of fields for current record
  
  def initialize(exe)
    super(exe)
    @fs = /\s+/
    @nf = 0 # number of fields for a record
    @acts = []
    @beg_act  = nil
    @end_act = nil
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
  
  def begin(&block)
    @beg_act = block
    self
  end

  def end(&block)
    @end_act = block
    self
  end
  
end
