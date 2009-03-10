
require 'pp'
require 'fileutils'

module Rubish
  class << self
    def repl
      ss = Rubish::Session.new
      ss.repl
    end

    # dup2 the given i,o,e to stdin,stdout,stderr
    # close all other file descriptors.
    def set_stdioe(i,o,e)
      $stdin.reopen(i)
      $stdout.reopen(o)
      $stderr.reopen(e)
      ObjectSpace.each_object(IO) do |io|
        unless io.closed? || [0,1,2].include?(io.fileno)
          io.close
        end
      end
    end
    attr_accessor :session
  end
end

class IO
  def pp(obj)
    PP.pp(obj,self)
    return nil
  end
end

# abstract class all executable rubish objects descend from
# executable objects read and write from IO
## they usually don't return anything, but they
## would have methods defined to make their io
## streams available to ruby to process (i.e. Rubish::Command#each)
#
# Rubish::Command < Rubish::Executable
# Rubish::CommandBuilder < Rubish::Command
# Rubish::Pipe < Rubish::Executable
class Rubish::Executable
  # stub, see: executable.rb
  def exec
    raise "implemented in executable.rb"
  end
end

# objects that rubish shell tries to eval to return an ruby value.
# Rubish::Awk < Rubish::Evaluable
class Rubish::Evaluable
  def eval
    raise "abstract"
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

load 'executable.rb'
load 'command.rb'
load 'command_builder.rb'
load 'pipe.rb'
load 'streamer.rb'
load 'sed.rb'
load 'awk.rb'
load 'session.rb'
