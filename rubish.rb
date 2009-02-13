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

class Rubish::Arguments
  # integeral key doesn't make sense.

  attr_reader :args, :keys
  def initialize
    @args = [] # to store the args
    @keys = {} # to store the position of the key arguments
  end
  
  def to_s
    @args.flatten.compact!.join " "
  end
  
  def [](key)
    args[keys[key]] if keys.has_key?(key)
  end

  def <<(obj)
    args << obj
  end

  def toggle(key,obj=nil)
    if self.has_key?(key)
      # r = args[keys[key]]
      args[keys[key]] = nil
      keys.delete(key)
      return false # kinda weird to return the toggled-off arguments
    else
      args << (obj ? [key,obj] : [key])
      keys[key] = args.length - 1
      return true
    end
  end

  def has_key?(key)
    keys.has_key?(key)
  end

  def concat(key,array)
    if self.has_key?(key)
      args[keys[key]].concat array
    else
      self.toggle(key,array)
    end
  end

  def delete(key)
    if self.has_key?(key)
      return args.toggle(key)
    else
      nil
    end
  end

  def inspect
    "<#{self.class}: #{self.to_s}>"
  end
end

class Rubish::Command
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
    def build(cmd,args)
      self.new(cmd,args)
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
  def initialize(cmd,args)
    @exe = cmd
    @status = nil
    @args = args.join " "
    @cmd = "#{exe} #{args}"
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

  def each_
    # send output lines to block if command is not already redirected
    if output.nil?
      r,w = IO.pipe
      @output = w
      pid = self.exec_
      w.close
      old_trap = Signal.trap("CHLD") do
        r.close
      end
      Signal.trap("CHLD",&old_trap)
      r.each_line do |l|
        yield(l)
      end
      _pid, status = Process.waitpid2(pid)
      if status != 0
        raise BadStatus.new(status)
      end
    end
    return nil
  end

  def each
    self.each_ do |l|
      Rubish.session.submit(yield(l))
    end
  end

  def map
    acc = []
    self.each_ do |l|
      acc << yield(l)
    end
    acc
  end

  def to_s
    self.cmd
  end

  def i(i)
    @input = i
    self
  end

  def o(o)
    @output = o
    self
  end
  
  def io(i=nil,o=nil)
    @input = i
    @output = o
    self
  end

end

class Rubish::CommandBuilder < Rubish::Command
  attr_reader :a
  def initialize
    @a = Rubish::Arguments.new
  end

  def cmd
    "#{a.to_s}"
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
      @cmds << Rubish::Command.new(m,args,block)
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

  def initialize
    @vars = {}
  end

  # calling private method also goes here
  def mu_handler(m,args,block)
    # block's not actually used
    raise "command builder doesn't take a block" unless block.nil?
    m = m.to_s
    Rubish::Command.new(m,args)
  end

  def repl
    # don't ever try to do anything with mu except Mu#__instance_eval
    raise "$stdin is not a tty device" unless $stdin.tty?
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
    # don't print nil
    ## this special case is nauseating, but it fits the Unix cmd line
    ## processing model better, where non matched lines (nil) are just
    ## swallowed.
    return if r.nil?
    # if r is an executable type supported by Rubish, execute it.
    if r.is_a?(Rubish::Command) ||
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
