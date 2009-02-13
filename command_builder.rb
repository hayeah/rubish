
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

class Rubish::CommandAbstraction < Rubish::Command
  attr_reader :a
  def initialize
    @a = Rubish::Arguments.new
  end

  def cmd
    "#{a.to_s}"
  end
end
