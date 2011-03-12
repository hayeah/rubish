require "spec_helper"
require 'tempfile'

describe "IO" do
  context "redirection" do
    it "redirects STDOUT to ruby pipes" do
      file = fixture("numbers")
      Rubish do
        output = nil
        cat(file).o { |p| output = p.readlines }.exec
        output.should == ["1\n","2\n","3\n"]
      end
    end

    it "redirects STDOUT to a file" do
      file = fixture("numbers")
      Rubish do
        output_file = Tempfile.new("tmp").path
        cat(file).o(output_file).exec
        File.readlines(output_file).should == ["1\n","2\n","3\n"]
      end
    end
    
    it "redirects STDIN to ruby pipes" do
      Rubish do
        cat.i {|p| p.puts([1,2,3]) }.map
      end.should == ["1","2","3"]
    end

    it "redirects STDIN to a file" do
      file = fixture("numbers")
      Rubish do
        cat.i(file).map
      end.should == ["1","2","3"]
    end
  end

  describe "closing an IO" do
    it "closes the input pipe after execution" do
      pipe = nil
      Rubish do
        cat.i {|p| pipe = p; p.puts([1,2,3]) }.map
      end
      pipe.should be_closed
    end

    it "closes the output pipe after execution" do
      pipe = nil
      Rubish do
        cat.i {|p| p.puts([1,2,3])}.o {|p| pipe = p; p.readlines }.exec
      end
      pipe.should be_closed
    end
  end
end
