class Rubish::Sed < Rubish::Streamer
  
  def initialize(exe)
    super(exe)
  end
  
  def q
    self.quit
  end

  def s(regexp,sub)
    line.sub!(regexp,sub)
    return line
  end

  def gs(regexp,sub)
    line.gsub!(regexp,sub)
    return line
  end

  def p(string=nil)
    self.puts(string || line)
  end

  private

  def stream_begin
  end

  def init_line
  end

  def stream_end
  end
  

end
