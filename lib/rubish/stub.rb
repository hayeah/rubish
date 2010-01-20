
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

def Rubish(&__block)
  Rubish::Context.global.eval {
    begin
      self.eval(&__block)
    ensure
      waitall
    end
  }
end


# Rubish::UnixExecutable < Rubish::Executable
# Rubish::Command < Rubish::UnixExecutable
# Rubish::Pipe < Rubish::UnixExecutable
#
# Rubish::Streamer < Rubish::Executable
# Rubish::Sed < Rubish::Streamer
# Rubish::Awk < Rubish::Streamer
#
# Rubish::BatchExecutable < Rubish::Executable
class Rubish::Executable
  # stub, see: executable.rb
  def exec
    raise "implemented in executable.rb"
  end
end

# This is an object that doesn't respond to anything.
#
# This provides an empty context for instance_eval (__instance_eval
# for the Mu object). It catches all method calls with method_missing.
# It is All and Nothing.
class Rubish::Mu
  
  self.public_instance_methods.each do |m|
    # for consistency's sake, methods already
    # underscored should also be aliased, but we
    # don't undefine it.
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
