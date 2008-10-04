# to start,
#
# s = Rubish::Session.new
# s.repl
## now you have a prompt
#
# any missing method is considered a bash command.
# args are Strings
# option flags are Symbols
#
## list directory
# > ls
# > ls :lh
# > ls :lh, "~"
#
# no safe quoting yet, so play safe.
#
# Rubish is designed to interface well with ruby. Usually a shell
# command just outputs and returns the exit status. To get a value,
# pass a block in,
#
# > ls{}
# skip the first line, select all sym links in directory
# > ls(:lh,"~"){}[1..-1].select {|l| l =~ /->/ }
#
# What does a block to shell comand do? It's a meta syntax to set
# various shell options.
#
# > ls{} # is actually a short hand for,
# > ls{objectify} # the default objectifier is :split_lines. You can define something eles.
# > ls{objectify(:some_other_objectifier)}
#
# The same mechanism is used for io redirection, but not implemented yet.
#
# > ls { in="some-file"; out="some-other-file"}


require 'pp'
require 'fileutils'

module Rubish
  class << self
    attr_accessor :session
  end
end

# This is an object that doesn't respond to anything.
#
# This provides an empty context for instance_eval (__instance_eval
# for the Mu object). It catches all method calls with method_missing.
# It is All and Nothing. 
class Rubish::Mu
  class << self
    def singleton(*modules)
      mu = self.new
      modules.each do |mod|
        mu.__extend(mod)
      end
      mu
    end
  end
  
  self.public_instance_methods.each do |m|
    if m[0..1] != "__"
      self.send(:alias_method,"__#{m}",m)
      self.send(:undef_method,m)
    end 
  end
  
  def initialize(&block)
    @missing_method_handler = block
  end

  def method_missing(method,*args,&block)
    if @missing_method_handler
      @missing_method_handler.call(method,args,block)
    else
      print "missing: #{method}"
      print "args:"
      pp args
      puts "block: #{block}"
    end
  end
end

class Rubish::Objectifier
  def split_lines(output)
    output.split "\n"
  end
end

class Rubish::Bash
  class BashError < RuntimeError
  end

  class SyntaxError < BashError
  end
  
  class BadStatus < BashError
    attr_reader :status, :reason
    def initialize(status,reason)
      @status = status
      @reason = reason
    end

    def to_s
      "#{status}: #{reason}"
    end
  end

  class << self
    def build(cmd,args,&block)
      self.new(cmd,args,block)
    end
  end
  # sh = Bash.new(cmd,*args)
  # sh.exec
  #
  # for piping
  # sh.out = <io>
  # sh.in = <io>
  attr_reader :exe, :args, :status
  attr_reader :cmd, :opts
  def initialize(cmd,args,block)
    @exe = cmd
    @status = nil
    parse_args(args)
    if block
      # if we get a block, assume we are objectifying.
      self.send(:objectify)
      self.instance_eval(&block)
    end
    @cmd = build_command_string
  end

  def exec
    use_value = true if opts[:objectify] 
    
    r = []
    IO.popen(cmd) do |io|
      io.each_line do |line|
        if filter
          next if not(line =~ filter) 
        end 
        if use_value
          r << line.chomp!
        else
          puts line
        end
      end
    end
    
    @status = $?.exitstatus
    if status != 0
      reason = r
      raise BadStatus.new(status,reason)
    end
    
    if use_value
      if method = opts[:objectify]
        if method == true
          # use each line as is
        else
          r = objectifier.send(method,r)
        end 
      end 
    else 
      r = status 
    end
    return r
  end

  private

  attr_reader :bash_args, :filter, :range, :opts
  def parse_args(args)
    # filters
    # opts
    args = args.clone
    @bash_args = []
    loop do
      case args.first
      when String, Array, Symbol
        @bash_args << args.shift
      else
        break
      end 
    end
    @bash_args = @bash_args.flatten

    @filter = nil
    @range = nil
    loop do
      case args.first
      when Regexp
        syntax_error "Only one filter is allowed" if @filter
        @filter = args.shift
      when Integer, Range
        syntax_error "Only one range is allowed" if @range
        syntax_error "Integer and Range not supported as filter yet"
      else
        break
      end
    end

    # meta options are optional
    if !args.empty?
      @opts = args.shift
      syntax_error "last argument should be hash of meta options: #{@opts}" if !@opts.is_a?(Hash)
    else
      @opts = {}
    end
    
    syntax_error "left over arguments: #{args.join ","}" if args.length > 0 
  end

  def build_command_string 
    args = bash_args.map do |arg|
      case arg
      when Symbol
        "-#{arg}"
      when String
        arg # should escape for bash
      else
        syntax_error "bash arg should be a Symbol or String: #{arg}" 
      end
    end
    "#{exe} #{args.join " "}"
  end

  def syntax_error(reason)
    raise SyntaxError.new(reason)
  end

  # be careful that order that options are specified shouldn't affect output.
  def objectify(value=true) 
    opts[:objectify] = value
  end

  def objectifier
    Rubish.session.objectifier
  end
  
end

class Rubish::Pipe
  attr_reader :cmds
  def initialize(&block)
    @cmds = []
    mu = Rubish::Mu.new &(self.method(:mu_handler).to_proc)
    mu.__instance_eval(&block)
  end

  def mu_handler(m,args,block)
    if m == :ruby
      @cmds << [args,block]
    else
      @cmds << Rubish::Bash.new(m,args,block)
    end
  end
end

module Rubish::Base
  def cd(dir)
    FileUtils.cd File.expand_path(dir) 
  end
end

class Rubish::Session

  attr_accessor :objectifier
  def initialize
    @objectifier = Rubish::Objectifier.new 
  end
  
  # calling private method also goes here
  def mu_handler(m,args,block) 
    m = m.to_s
    bash = Rubish::Bash.new(m,args,block)
    bash.exec
  end

  def repl
    # don't ever try to do anything with mu except Mu#__instance_eval
    mu = Rubish::Mu.new &(self.method(:mu_handler).to_proc)
    mu.__extend Rubish::Base
    begin
      attach_session
      loop do
        line = read
        if line
          begin
            pp mu.__instance_eval(line)
          rescue StandardError, ScriptError => e
            puts e
          end
        else
          next
        end 
      end
    ensure
      detach_session
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
