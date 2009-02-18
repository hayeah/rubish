
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

# abstract class all executable rubish objects descend from
class Rubish::Executable
  attr_reader :io_in
  attr_reader :io_out
  attr_reader :io_err

  def initialize(*args)
    # ignore the args. This is so children classes
    # can call "super" even if their initializers
    # take arguments.
    @io_in = $stdin
    @io_out = $stdout
    @io_err = $stderr
  end
  
  def exec
    raise "abstract"
  end

  # methods for io redirection

  def i(i)
    @io_in =  __get_io i
    self
  end

  def o(o)
    @io_out =  __get_io o
    self
  end

  def err(e)
    @io_err =  __get_io e
    self
  end
  
  def io(i=nil,o=nil)
    i(i); o(o)
    self
  end

  private
  def __get_io(val)
    case val
      
#     when String
#       raise "not a file" unless File.file?(File.expand_path(val))
#       File.new(val,"r")
      
    when Integer
      IO.new(val)
    when IO
      val
    else
      raise "not a valid input: #{val}"
    end
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

load 'command.rb'
load 'command_builder.rb'
load 'pipe.rb'
load 'awk.rb'
load 'session.rb'
