# load 'rubish.rb' ; ss = Rubish::Session.new ; ss.repl
#
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
    def repl
      ss = Rubish::Session.new
      ss.repl
    end
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

class Rubish::BashCommand
  class BashError < RuntimeError
  end

  class SyntaxError < BashError
  end

  class BadStatus < BashError
    attr_reader :status
    def initialize(status)
      @status = status
    end

    def to_s
      "<##{self.class}: #{status}>"
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
  attr_reader :input, :output
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
    pid = self.exec_

    _pid, status = Process.waitpid2(pid) # sync

    if status != 0
      raise BadStatus.new(status)
    end
    return nil
  end

  def exec_
    unless pid = Kernel.fork
      # child
      begin
        $stdin.reopen(input) if input
        $stdout.reopen(output) if output
        Kernel.exec(self.cmd)
      rescue
        puts $!
        cmd_name = self.cmd.split.first
        $stderr.puts "#{cmd_name}: command not found"
        Kernel.exit(127) # that's the bash exit status.
      end
    end
    return pid
  end

  def each
    IO.popen(self.cmd) do |pipe|
      pipe.each_line do |line|
        line = line.chomp!
        r = yield(line)
        # the trick here is that if r happens to be a cmd, it would be executed.
        Rubish.session.submit(r)
      end
    end
    return nil
  end

  def to_s
    self.cmd
  end

  def io(i=nil,o=nil)
    @input = i
    @output = o
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
    @lines = nil
    loop do
      case args.first
      when Regexp
        syntax_error "Only one filter is allowed" if @filter
        @filter = args.shift
      when Integer
        syntax_error "Only one range is allowed" if @range
        @range = args.shift
      when Range
        syntax_error "Only one range is allowed" if @range
        @range = args.shift
        syntax_error "invalid range: #{@range}" if @range.max < @range.min
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
    if block
      mu = Rubish::Mu.new &(self.method(:mu_handler).to_proc)
      mu.__instance_eval(&block)
    end
    # dun wanna handle special case for now
    raise "pipe length less than 2" if @cmds.length < 2
  end

  def mu_handler(m,args,block)
    if m == :ruby
      raise "not supported yet"
      @cmds << [args,block]
    else
      @cmds << Rubish::BashCommand.new(m,args,block)
    end
  end

  def exec
    # pipes == [i0,o1,i1,o2,i2...in,o0]
    # i0 == $stdin
    # o0 == $stdout
    pipe = nil # r, w
    @cmds.each_index do |index|
      if index == 0 # head
        i = $stdin
        pipe = IO.pipe
        o = pipe[1] # w
      elsif index == (@cmds.length - 1) # tail
        i = pipe[0]
        o = $stdout
      else # middle
        i = pipe[0] # r
        pipe = IO.pipe
        o = pipe[1]
      end

      cmd = @cmds[index]
      if child = fork # children
        #parent
        i.close unless i == $stdin
        o.close unless o == $stdout
      else
        $stdin.reopen(i)
        $stdout.reopen(o)
        Kernel.exec cmd.cmd
      end
    end
    
    ps = Process.waitall
    #pp ps
  end
end

module Rubish::Base
  def cd(dir)
    FileUtils.cd File.expand_path(dir)
  end

  def p(&block)
    Rubish::Pipe.new &block
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
    Rubish::BashCommand.new(m,args,block)
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
    # if r is a cmd, execute it.
    #
    # don't print nil
    ## this special case is nauseating, but it fits the Unix cmd line
    ## processing model better, where non matched lines (nil) are just
    ## swallowed.
    if r.is_a?(Rubish::BashCommand) ||
       r.is_a?(Rubish::Pipe)
      # is a bash command, so execute it.
      r.exec
    elsif r
      # normal ruby value
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
