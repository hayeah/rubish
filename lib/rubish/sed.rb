class Rubish::Sed < Rubish::Executable
  include Rubish::Streamer

  def initialize(exe)
    init_streamer
    @exe = exe
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

  def exec_with(_i,o,_e)
    @exe.pipe_out do |pipe|
      process_stream(pipe,o)
    end
  end

  def stream_begin
  end

  def init_line
  end

  def stream_end
  end

  

end
