
class Rubish::Arguments
  # integeral key doesn't make sense.

  attr_reader :args, :keys
  def initialize
    @args = [] # to store the args
    @keys = {} # to store the position of the key arguments
  end
  
  def to_s
    @args.flatten.compact!
    @args.join " "
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

  def set(key,val=nil)
    if self.has_key?(key)
      self.delete(key)
    end
    self.toggle(key,val)
  end

  def has_key?(key)
    keys.has_key?(key)
  end

  def push(key,val)
    self.concat(key,[val])
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

class Rubish::CommandBuilder < Rubish::Command
  attr_reader :args
  class << self
    def inherited(klass)
      puts "inherited by #{klass}"
      klass.instance_eval do
        def as(name)
          self.instance_eval("def cmd_name; '#{name}'; end")
        end
      end
    end
  end
  
  def initialize
    @args = Rubish::Arguments.new
  end

  def set(key,val=nil)
    args.set(key,val)
    self
  end

  def toggle(key,val=nil)
    args.toggle(key,val)
    self
  end
  
  def opts(v)
    case v
    when Array
      args << v
    when Hash
      v.each do |k,v|
        args.push(k,v)
      end
    end
    self
  end
  
  def cmd
    "#{self.class.cmd_name} #{args.to_s}"
  end
end
