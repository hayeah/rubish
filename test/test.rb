#!/usr/bin/env ruby

# note that report of assertions count is
# zero. Probably because we are doing assert in
# workspace rather than Test

require File.dirname(__FILE__) + '/../lib/rubish'
require 'rubygems'
require 'pp'
require 'test/unit'
require 'thread'
gem 'thoughtbot-shoulda'
require 'shoulda'

require 'set'
  
if ARGV.first == "dev"
  TUT_ = Test::Unit::TestCase
  # create a dummy empty case to disable all tests
  # except the one we are developing
  class TUT
    def self.should(*args,&block)
      nil
    end

    def self.context(*args,&block)
      nil
    end
  end
else
  TUT = Test::Unit::TestCase
end


TEST_DIR = File.expand_path(File.dirname(__FILE__)) + "/tmp"

Rubish.new_session
WS = Rubish.session.current_workspace
WS.extend Test::Unit::Assertions

def setup_tmp
  WS.eval {
    rm(:rf, TEST_DIR).exec if File.exist?(TEST_DIR)
    mkdir(TEST_DIR).exec
    cd TEST_DIR
  }
end

setup_tmp

module IOHelper
  class << self
    def created_ios
      set1 = Set.new
      set2 = Set.new
      ObjectSpace.each_object(IO) { |o| set1 << o }
      yield
      ObjectSpace.each_object(IO) { |o| set2 << o }
      set2 - set1
    end
  end
end

class Rubish::Test < TUT

  def setup
    setup_tmp
  end

  should "not have changed directory" do
    WS.eval {
      assert_equal TEST_DIR, pwd.first
      mkdir("dir").exec
      cd "dir" do
        assert_equal "#{TEST_DIR}/dir", pwd.first
      end
      assert_equal TEST_DIR, pwd.first
    }
  end

  should "have changed directory" do
    WS.eval {
      assert_equal TEST_DIR, pwd.first
      mkdir("dir").exec
      cd "dir"
      assert_equal "#{TEST_DIR}/dir", pwd.first
      cd TEST_DIR
      assert_equal TEST_DIR, pwd.first
    }
  end
end

class Rubish::Test::Executable < TUT
  def setup
    setup_tmp
  end
  
  context "io" do
    should "chomp lines for each/map" do
      WS.eval {
        ints = (1..100).to_a.map { |i| i.to_s }
        cat.o("output").i { |p| p.puts(ints)}.exec
        # raw access to pipe would have newlines
        cat.i("output").o do |p|
          p.each { |l| assert l.chomp!
          }
        end.exec
        # iterator would've chomped the lines
        cat.i("output").each do |l|
          assert_nil l.chomp!
        end
      }
    end
    
    should "redirect io" do
      WS.eval {
        ints = (1..100).to_a.map { |i| i.to_s }
        cat.o("output").i { |p| p.puts(ints)}.exec
        assert_equal ints, cat.i("output").map
        assert_equal ints, p { cat; cat; cat}.i("output").map
        assert_equal ints, cat.i { |p| p.puts(ints) }.map
      }
    end

    should "close pipes used for io redirects" do
      WS.eval {
        ios = IOHelper.created_ios do
          cat.i { |p| p.puts "foobar" }.o { |p| p.readlines }.exec
        end
        assert ios.all? { |io| io.closed? }
        ios = IOHelper.created_ios do
          cat.i { |p| p.puts "foobar" }.o("output").exec
        end
        assert ios.all? { |io| io.closed? }
      }
    end

    should "not close stdioe" do
      WS.eval {
        assert_not $stdin.closed?
        assert_not $stdout.closed?
        assert_not $stderr.closed?
        ios = IOHelper.created_ios do
          ls.exec
        end
        assert ios.empty?
        assert_not $stdin.closed?
        assert_not $stdout.closed?
        assert_not $stderr.closed?
      }
    end
    
    should "not close io if redirecting to existing IO object" do
      WS.eval {
        begin
          f = File.open("/dev/null","w")
          ios = IOHelper.created_ios do
            ls.o(f).exec
          end
          assert ios.empty?
          assert_not f.closed?
        ensure
          f.close
        end
      }
    end
    
  end
  
  should "head,first/tail,last" do
    WS.eval {
      ls_in_order = p { ls; sort :n }
      files = (1..25).to_a.map { |i| i.to_s }
      exec touch(files)
      assert_equal 25, ls.map.size
      assert_equal 1, ls.head.size
      assert_equal "1", ls_in_order.first
      assert_equal \
       (1..10).to_a.map { |i| i.to_s },
       ls_in_order.head(10)
      assert_equal 25, ls.head(100).size

      assert_equal 1, ls.tail.size
      assert_equal "25", ls_in_order.last
      assert_equal \
       (16..25).to_a.map { |i| i.to_s },
       ls_in_order.tail(10)
      assert_equal 25, ls.tail(100).size
    }
  end
  
  should "quote exec arguments" do
    WS.eval {
      files = ["a b","c d"]
      # without quoting
      exec touch(files)
      assert_equal 4, ls.map.size
      exec rm(files)
      assert_equal 0, ls.map.size
      # with quoting
      exec touch(files).q
      assert_equal 2, ls.map.size
      exec rm(files).q
      assert_equal 0, ls.map.size
      
    }
  end
  
end

class Rubish::Test::Workspace < TUT
  # Remember that Object#methods of Workspace
  # instances are aliased with the prefix '__'
  
  def setup
    setup_tmp
  end

  should "alias Object#methods" do
    assert_instance_of Rubish::Command, WS.class
    # it's somewhat surprising that
    # assert_instance_of still works. Probably not
    # using Object#class but case switching.
    assert_instance_of Rubish::Workspace, WS
    assert_instance_of Class, WS.__class

    # the magic methods should still be there
    assert WS.__respond_to?(:__id__)
    assert WS.__respond_to?(:__send__)

    # the magic methods should be aliased as well
    assert WS.__respond_to?(:____id__)
    assert WS.__respond_to?(:____send__)

  end

  should "not introduce bindings to parent workspace" do
    WS.derive {
      def foo1
        1
      end
    }.eval {
      assert_not_equal derived_workspace, WS
      # the derived workspace should have the
      # injected binding via its singleton module.
      derived_workspace = self
      assert_equal 1, foo1
      WS.eval {
        assert_instance_of Rubish::Command, foo1, "the original of derived workspace should not respond to injected bindings"
      }
    }
  end
end

class Rubish::Test::Context < TUT
  def setup
    setup_tmp
  end

  module Helper
    class << self
      def workspace
        # a custom workspace extended with two methods and assertions
        ws = Rubish::Workspace.new.extend Module.new {
          def foo1
            1
          end

          def foo2
            2
          end
        }, Test::Unit::Assertions
      end

      def context(i=nil,o=nil,e=nil)
        context = Rubish::Context.new(workspace,i,o,e)
      end
    end
  end
  

  should "stack contexts" do
    c1 = Helper.context("c1")
    c2 = Helper.context("c2")
    c1.for {
      # the following "context" is a binding
      # introduced by the default workspace. It
      # should point to the current active context.
      assert_instance_of Rubish::Context, context
      assert_same Rubish::Context.current, context
      assert_same c1, context
      c2.for {
        assert_same c2, context
      }
    }
  end
  
  should "use context specific workspace" do
    Helper.context.for {
      assert_equal 1, foo1
      assert_equal 2, foo2
      cmd = ls
      assert_instance_of Rubish::Command, cmd
    }
  end

  should "use context specific IO" do
    output = "output"
    Helper.context(nil,output,nil).for {
      
      assert_equal output, Rubish::Context.current.o
      cat.i { |p| p.puts 1}.exec
      assert_equal 1, cat.i("output").first.to_i
    }
  end
  
end

class Rubish::Test::UnixJob < TUT
  
  def setup
    setup_tmp
  end

  module Helper
    class << self
      def time_elapsed
        t1 = Time.now
        yield
        return Time.now - t1
      end

      def slowcat(n)
        WS.eval {
          lines = (1..n).to_a
          ruby("../slowcat.rb").i { |p| p.puts lines }
        }
      end
    end
  end

  should "set result to array of exit statuses" do
    WS.eval {
      ls.exec.result.each { |status|
        assert_instance_of Process::Status, status
        assert_equal 0, status.exitstatus
      }
    }
  end

  should "map in parrallel to different array" do
    slow = Helper.slowcat(1)
    a1, a2, a3 = [[],[],[]]
    j1 = slow.map! a1
    j2 = slow.map! a2
    j3 = slow.map! a3
    js = [j1,j2,j3]
    t = Helper.time_elapsed {
      js.each { |j| j.wait }
    }
    assert_in_delta 1, t, 0.1
    assert j1.ok? && j2.ok? && j3.ok?
    rs = [a1,a2,a3]
    # each result should be an array of sized 3
    assert(rs.all? { |r| r.size == 1 })
    # should be accumulated into different arrays
    assert_equal(3,rs.map{|r| r.object_id }.uniq.size)
  end

  should "map in parrallel to thread safe queue" do
    slow = Helper.slowcat(1)
    acc = Queue.new
    j1 = slow.map! acc
    j2 = slow.map! acc
    j3 = slow.map! acc
    js = [j1,j2,j3]
    t = Helper.time_elapsed {
      j1.wait; j2.wait; j3.wait
    }
    assert_in_delta 1, t, 0.1
    assert j1.ok? && j2.ok? && j3.ok?
    # each result should be an array of sized 3
    assert_equal 3, acc.size
  end

  should "wait for job" do
    job = Helper.slowcat(1).exec!
    assert_equal false, job.done?
    assert_equal false, job.ok?
    t = Helper.time_elapsed { job.wait }
    assert_in_delta 0.1, t, 1
    assert_equal true, job.done?
    assert_equal true, job.ok?
  end
  
  should "raise when waited twice" do
    assert_raise(Rubish::Error) {
      WS.eval { ls.exec.wait }
    }
    assert_raise(Rubish::Error) {
      WS.eval { ls.exec!.wait.wait }
    }
  end

  should "kill a job" do
    acc = []
    t = Helper.time_elapsed {
      job = Helper.slowcat(10).map!(acc)
      sleep(2)
      job.stop!
    }
    assert_in_delta 2, acc.size, 1, "expects to get roughly two lines out before killing process"
    assert_in_delta 2, t, 0.1
    
  end

    
  # should "add to job control" do
#     WS.eval {
#       slow = Helper.slowcat(1).o "/dev/null"
#       job1 = slow.exec!
#       job2 = slow.exec!
#       assert_kind_of Rubish::Job, job1
#       assert_kind_of Rubish::Job, job2
#       assert_equal 2, jobs.values.size
#       waitall
#       assert_equal 0, jobs.values.size
#     }
#   end
  
#   # we'll do a bunch of timing tests to see if parallelism is working
#   should "wait" do
#     WS.eval {
#       slow = Helper.slowcat(3)
#       puts
#       puts "slowcat 3 lines"
#       t = Helper.time_elapsed { slow.exec }
#       assert_in_delta 3, t, 1
#       assert jobs.empty?
#       slow = Helper.slowcat(2)
#       puts "slowcat 2 * 3 lines in sequence"
#       t = Helper.time_elapsed { slow.exec; slow.exec; slow.exec }
#       assert_in_delta 6, t, 1
#       assert jobs.empty?
#     }
#   end

#   should "not wait" do
#     WS.eval {
#       slow = Helper.slowcat(3)
#       puts
#       puts "slowcat 3 * 4 lines in parallel"
#       t = Helper.time_elapsed { slow.exec! ; slow.exec!; slow.exec!; slow.exec! }
#       # should not wait
#       assert_in_delta 0, t, 0.5
#       assert_equal 4, jobs.values.size
#       ## the above jobs should finish more or less within 3 to 6 seconds
#       t = Helper.time_elapsed { waitall }
#       assert_in_delta 3, t, 1
#       assert_equal 0, jobs.values.size
#     }
#   end
  
end
