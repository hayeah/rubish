require 'spec_helper'

describe Rubish::Executable do
  describe "output processing" do
    def numbers
      file = fixture("numbers")
      Rubish { cat(file) }
    end
    
    it "first line of output" do
      numbers.first.should == "1"
    end

    it "last line of output" do
      numbers.last.should == "3"
    end

    it "tail of output" do
      numbers.tail(2).should == ["2","3"]
    end

    it "head of output" do
      numbers.head(2).should == ["1","2"]
    end

    it "maps output to array" do
      numbers.map.should == ["1","2","3"]
    end

    it "processes output to by line" do
      acc = []
      numbers.each { |l|
        acc << l
      }
      acc.should == ["1","2","3"]
    end
  end
end
