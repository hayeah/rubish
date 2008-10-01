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
    
    def build(cmd,*args,&block) 
      if block
        bash = self.new(cmd,*args,&block)
      else
        bash = self.new(cmd,*args) 
      end
      bash
    end 
    
    def exec(cmd,*args,&block)
      if block
        bash = self.build(cmd,*args,&block)
      else
        bash = self.build(cmd,*args) 
      end
      bash.exec
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
  def initialize(cmd,*args,&block)
    @exe = cmd
    @args = args 
    @opts = {}
    @status = nil
    parse_args
    if block
      # if we get a block, assume we are objectifying.
      self.send(:objectify)
      self.instance_eval(&block)
    end
    @cmd = build_command_string
  end

  def exec
    use_value = !opts.empty?
    r = `#{cmd}`

    @status = $?.exitstatus
    if status != 0
      reason = r
      raise BadStatus.new(status,reason)
    end
    
    if use_value
      if objectifier = opts[:objectify]
        r=self.send(objectifier,r)
      end 
    else
      puts r
      r = status 
    end
    return r
  end

  private
  def parse_args
    if args.last.is_a? Regexp
      raise "this is probably stupid. Don't support it."
      opts = args.pop
      opts = /\/(.*)\//
      flags = $1
      process_flags(flags) if !flags.empty?
    end
  end

#   def process_flags(flags)
#     flags.each_byte do |c|
#       case c
#       when ?o
#         self.objectify
#       else
#         raise SyntaxError.new "unknown bash flag: #{c}"
#       end
#     end
#   end

  def build_command_string 
    args.map! do |arg|
      case arg
      when Symbol
        "-#{arg}"
      when String
        arg # should escape for bash
      else
        raise SyntaxError.new "bash arg should be a Symbol or String: #{arg}"
      end
    end
    "#{exe} #{args.join " "}"
  end

  # be careful that order that options are specified shouldn't affect output.
  def objectify(value=:split_lines)
    # if a symbol, call that symbol as method when objectifying
    # the basic objectifier simply split output into lines
    opts[:objectify] = value
  end
  
  def split_lines(output)
    output.split "\n"
  end
end

class Rubish::Session
  
  # calling private method also goes here
  def method_missing(m,*args,&block) 
    m = m.to_s
    if block
      bash = Rubish::Bash.build(m,*args,&block)
    else
      bash = Rubish::Bash.build(m,*args)
    end 
    bash.exec
  end

  def cd(dir)
    FileUtils.cd File.expand_path(dir)
  end

  def repl
    loop do
      line = read
      if line
        pp self.instance_eval(line)
      else
        next
      end 
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

  private
  def foo
    "foo"
  end

end
