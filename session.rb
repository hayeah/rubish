
class Rubish::Session

  module Base
    def cd(dir)
      FileUtils.cd File.expand_path(dir)
    end

    def p(&block)
      Rubish::Pipe.new &block
    end

    def awk
      Rubish::Awk.new
    end
  end

  def initialize
    @vars = {}
  end

  # calling private method also goes here
  def mu_handler(m,args,block)
    # block's not actually used
    raise "command builder doesn't take a block" unless block.nil?
    m = m.to_s
    Rubish::Command::ShellCommand.new(m,args)
  end

  def repl
    # don't ever try to do anything with mu except Mu#__instance_eval
    raise "$stdin is not a tty device" unless $stdin.tty?
    mu = Rubish::Mu.new &(self.method(:mu_handler).to_proc)
    mu.__extend Rubish::Session::Base
    begin
      attach_session
      loop do
        line = read
        if line
          begin
            r = mu.__instance_eval(line)
            self.submit(r)
          rescue StandardError, ScriptError => e
            puts e
            puts e.backtrace
          end
        else
          next
        end
      end
    ensure
      detach_session
    end
  end

  def submit(r)
    # don't print nil
    ## this special case is nauseating, but it fits the Unix cmd line
    ## processing model better, where non matched lines (nil) are just
    ## swallowed.
    if r.is_a?(Rubish::Executable)
      r.exec
      # hmmm... should it do anything with the return value of r.exec?
    elsif r.is_a?(Rubish::Evaluable)
      submit(r.eval)
    else r
      pp r
    end
  end

  def attach_session
    Rubish.session = self
  end

  def detach_session
    if Rubish.session == self
      Rubish.session = nil
    else
      raise "#{self} is not attached"
    end
  end

  def read
    line = Readline.readline('> ')
    Readline::HISTORY.push(line) if !line.empty?
    line
  end

  def history
  end

  alias_method :h, :history

end
