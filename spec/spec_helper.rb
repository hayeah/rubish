$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'rubish'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

def fixture(name)
  File.expand_path("../fixtures/#{name}",__FILE__)
end

module Helpers
end

module Helpers::Commands
  extend self

  # a command that does not return until n-milleseconds later
  def slow(n)
    # p File.expand_path("../script/slowcat.rb",__FILE__)
    Rubish do
      ruby(File.expand_path("../script/slowcat.rb",__FILE__),n.to_s)
    end
  end
end

RSpec.configure do |config|
  
end
