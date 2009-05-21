
module Rubish
  # magic singleton value to supress shell output.
  module Null
  end

  class Error < RuntimeError
  end
  
  class << self
    def repl
      Repl.repl
    end

    # def reload
#       (%w{
# rubish/stub
# rubish/job
# rubish/job_control
# rubish/session
# rubish/workspace
# rubish/executable
# rubish/command
# rubish/command_builder
# rubish/pipe
# rubish/streamer} +
#        %w{
# rubish/sed
# rubish/awk
# }).each {|e| $".delete(e + '.rb') }
#       require 'rubish'
#       repl
#     end

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
# Rubish::Awk < Rubish::Executable
class Rubish::Executable
  # stub, see: executable.rb
  def exec
    raise "implemented in executable.rb"
  end
end

# not entirely sure if this makes sense anymore
# # objects that rubish shell tries to eval and return an ruby value.
# class Rubish::Evaluable < Rubish::Executable
#   def eval
#     raise "abstract"
#   end
# end

# This is an object that doesn't respond to anything.
#
# This provides an empty context for instance_eval (__instance_eval
# for the Mu object). It catches all method calls with method_missing.
# It is All and Nothing.
class Rubish::Mu
  
  self.public_instance_methods.each do |m|
    # for consistency's sake, methods already
    # underscored should remain be two undscores
    self.send(:alias_method,"__#{m}",m)
    if m[0..1] != "__"
      # don't remove special methods (i.e. __id__, __send__)
      self.send(:undef_method,m)
    end
  end

  def initialize(*modules,&block)
    raise "abstract"
  end

  def method_missing(*args,&block)
    raise "abstract"
  end
  
end
