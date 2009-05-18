
class Rubish::Repl
  class << self
    def repl
      self.new.repl
    end
  end

  def initialize
    @scanner = RubyLex.new
  end

  def repl
    raise "$stdin is not a tty device" unless $stdin.tty?
    raise "readline is not available??" unless defined?(IRB::ReadlineInputMethod)
    rl = IRB::ReadlineInputMethod.new

    @scanner.set_prompt do |ltype, indent, continue, line_no|
      # ltype is Delimiter type. In strings that are continued across a line break, %l will display the type of delimiter used to begin the string, so you'll know how to end it. The delimiter will be one of ", ', /, ], or `.
      if ltype or indent > 0 or continue
        p = ". "
      else
        p = "> "
      end
      if indent
        p << " " * indent
      end
      rl.prompt = p
    end
    
    @scanner.set_input(rl)

    @scanner.each_top_level_statement do |line,line_no|
      begin
        r = Rubish::Context.current.eval(line)
        if r.is_a?(Rubish::Executable)
          r.exec
        elsif r != Rubish::Null
          pp r
        end
      rescue StandardError, ScriptError => e
        puts e
        puts e.backtrace
      end
    end
  end
end
