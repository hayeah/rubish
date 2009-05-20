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
  TUT_ = Test::Unit::TestCase
end


TEST_DIR = File.expand_path(File.dirname(__FILE__)) + "/tmp"


RSH = Rubish::Context.global.derive
RSH.workspace.extend(Test::Unit::Assertions)
def rsh(&__block)
  if __block
    RSH.eval {
      begin
        self.eval(&__block)
      ensure
        waitall
      end
    }
  else
    return RSH
  end
end

def setup_tmp
  rsh {
    rm(:rf, TEST_DIR).exec if File.exist?(TEST_DIR)
    mkdir(TEST_DIR).exec
    cd TEST_DIR
  }
end

setup_tmp


module Helper
  class << self
    def cat(data)
      rsh {
        cat.i { |p| p.puts data}
      }
    end
    
    def time_elapsed
      t1 = Time.now
      yield
      return Time.now - t1
    end

    def slowcat(n)
      rsh {
        lines = (1..n).to_a
        ruby("../slowcat.rb").i { |p| p.puts lines }
      }
    end

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
      Rubish::Context.singleton.derive(nil,i,o,e)
    end
  end
end

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
    rsh {
      assert_equal TEST_DIR, pwd.first
      mkdir("dir").exec
      cd "dir" do
        assert_equal "#{TEST_DIR}/dir", pwd.first
      end
      assert_equal TEST_DIR, pwd.first
    }
  end

  should "have changed directory" do
    rsh {
      assert_equal TEST_DIR, pwd.first
      mkdir("dir").exec
      cd "dir"
      assert_equal "#{TEST_DIR}/dir", pwd.first
      cd TEST_DIR
      assert_equal TEST_DIR, pwd.first
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
    rsh {
      ws = current_workspace
      assert_instance_of Rubish::Command, ws.class
      # it's somewhat surprising that
      # assert_instance_of still works. Probably not
      # using Object#class but case switching.
      assert_instance_of Rubish::Workspace, ws
      assert_instance_of Class, ws.__class

      # the magic methods should still be there
      assert ws.__respond_to?(:__id__)
      assert ws.__respond_to?(:__send__)

      # the magic methods should be aliased as well
      assert ws.__respond_to?(:____id__)
      assert ws.__respond_to?(:____send__)
    }
    

  end

  should "not introduce bindings to parent workspace" do
    rsh {
      parent = current_workspace
      child = parent.derive {
        def foo
          1
        end
      }
      child.eval {
        assert_not_equal parent.__object_id, child.__object_id
        # the derived workspace should have the
        # injected binding via its singleton module.
        assert_equal 1, foo
        parent.eval {
          assert_instance_of Rubish::Command, foo, "the original of derived workspace should not respond to injected bindings"
        }
      }
    }
  end
end

class Rubish::Test::Workspace::Base < TUT
  def self
    setup_tmp
  end

  should "nest with's" do
    rsh {
      c1 = self
      with {
        ws2 = self
        # redefines foo each time this block is executed
        def foo
          1
        end
        
        assert_equal c1, context.parent
        assert_instance_of Rubish::Command, ls
        assert_equal 1, foo
        with {
          assert_equal c1, context.parent.parent
          assert_equal ws2, context.workspace
          assert_equal 1, foo
          acc = []
          c2 = with(current_workspace.derive {def foo; 3 end})
          c2.eval {
            assert_equal 3, foo
          }
          c2.eval {def foo; 33; end}
          c2.eval {assert_equal 33, foo}
          
          with(c1) { # explicitly derive from a specified context
            assert_equal c1, context.parent, "should derive from given context"
          }}}
      assert_instance_of Rubish::Command, foo
    }
  end
  
end

class Rubish::Test::IO < TUT

  def setup
    setup_tmp
  end

  should "chomp lines for each/map" do
    rsh {
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
    rsh {
      ints = (1..100).to_a.map { |i| i.to_s }
      cat.o("output").i { |p| p.puts(ints)}.exec
      assert_equal ints, cat.i("output").map
      assert_equal ints, p { cat; cat; cat}.i("output").map
      assert_equal ints, cat.i { |p| p.puts(ints) }.map
    }
  end

  should "close pipes used for io redirects" do
    rsh {
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
    rsh {
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
    rsh {
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

class Rubish::Test::Executable < TUT

  def setup
    setup_tmp
  end

  should "set result to good exits" do
    rsh {
      r = cat.i { |p| p.puts 1}.exec
      assert_equal 1, r.size
      assert_equal 0, r.first.exitstatus
    }
  end
    
  should "head,first/tail,last" do
    rsh {
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
    rsh {
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

  should "raise when exit status not zero" do
    rsh {
      
      r = assert_raise(Rubish::Job::Failure) {
        foobarqux_is_no_command.exec
      }
      
      begin
        foobarqux_is_no_command.exec
      rescue Rubish::Job::Failure => e
        j = e.job
        assert j.done?
        assert jobs.empty?
        # the result should be the processes that
        # exit properly. in this case, the empty
        # array.
        assert j.result.empty? 
        assert_equal 1, e.reason.exitstatuses.size
        assert_not_equal 0, e.reason.exitstatuses.first.exitstatus
      end
      
    }
  end
  
end

class Rubish::Test::Pipe < TUT
  def setup
    setup_tmp
  end

  should "build pipe with a block in workspace" do
    rsh {
      pipe = p { cat ; cat ; cat}
      assert_instance_of Rubish::Pipe, pipe
      assert_equal 3, pipe.cmds.length
      assert_equal 1, pipe.i { |p| p.puts 1 }.first.to_i

      # specify a workspace to build pipe with
      pipe2 = Rubish::Pipe.build(current_workspace.derive { def foo; abcde; end}) {
        foo
        foo
      }
      assert_equal 2, pipe2.cmds.length
      assert_equal "abcde", pipe2.cmds.first.cmd
    }
  end

  should "build pipe with an array" do
    rsh {
      # tee to 10 files along the pipeline
      tees = (1..10).map { |i| tee "o#{i}" }
      p(tees).i { |p| p.puts "1" }.exec
      assert_equal 10, ls.map.length
      (1..10).map { |i|
        assert_equal 1, cat("o#{i}").first.to_i
      }
    }
  end
end

class Rubish::Test::Streamer < TUT
  def setup
    setup_tmp
  end

  should "streamer should capture executable's output" do
    rsh {
      cataa = Helper.cat("aa")
      output = cataa.o
      assert_equal "aa", cataa.sed {p}.first
      assert_equal output, cataa.o
    }
  end

  should "allow streamer chain" do
    rsh {
      assert_equal "aa", Helper.cat("aa").sed { p }.sed { p }.sed { p }.first
    }
  end
  
  should "sed with s and gs" do
    rsh {
      # aa => iia => eyeeyea
      assert_equal "eyeeyea",  Helper.cat("aa").sed { s /a/, "ii"; gs /i/, "eye"; p}.first
    }
  end

  should "peek" do
    rsh {
      rs = Helper.cat((1..10).to_a).awk {
        collect(:three,[line,*peek(2)])
      }.end { three }.exec
      assert_equal [["1", "2", "3"],
                    ["2", "3", "4"],
                    ["3", "4", "5"],
                    ["4", "5", "6"],
                    ["5", "6", "7"],
                    ["6", "7", "8"],
                    ["7", "8", "9"],
                    ["8", "9", "10"],
                    ["9", "10"],
                    ["10"]], rs
    }
  end

  should "skip" do
    rsh {
      rs = Helper.cat((1..10).to_a).awk {
        collect(:three,[line,*peek(2)])
        skip(2)
      }.end { three }.exec
      assert_equal [["1", "2", "3"],
                    ["4", "5", "6"],
                    ["7", "8", "9"],
                    ["10"]], rs
      
    }
  end
  
  should "trigger by position" do
    assert_equal "1", Helper.cat((1..10).to_a).sed(:bof){p}.first
    assert_equal "10", Helper.cat((1..10).to_a).sed(:eof){p}.first
    assert_equal "1", Helper.cat((1..10).to_a).sed(1){p}.first
    assert_equal "10", Helper.cat((1..10).to_a).sed(-1){p}.first
    assert_equal ["1","10"], Helper.cat((1..10).to_a).sed(/1/){p}.map
    rs = Helper.cat((1..10).to_a).sed(1) { p "a1"; done}.act { p "b" + line }.map
    assert_equal rs, ["a1", "b2", "b3", "b4", "b5", "b6", "b7", "b8", "b9", "b10"]
  end

  should "trigger by range" do
    assert_equal ["3","4","5"], Helper.cat((1..10).to_a).sed(3,5) { p }.map
    assert_equal ["8","9","10"], Helper.cat((1..10).to_a).sed(8,:eof) { p }.map
    assert_equal \
      ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"],
      Helper.cat((1..10).to_a).sed(:bof,:eof) { p }.map
    assert_equal ["b","c","b"], Helper.cat(["a","a","b","c","b","a","a"]).sed(/b/,/b/) { p }.map
  end

end


class Rubish::Test::Context < TUT
  def setup
    setup_tmp
  end

  should "stack contexts" do
    c1 = Helper.context(nil,"c1_out")
    c2 = Helper.context(nil,"c2_out")
    c1.eval {
      # the following "context" is a binding
      # introduced by the default workspace. It
      # should point to the current active context.
      assert_instance_of Rubish::Context, context
      assert_equal Rubish::Context.current, context
      assert_equal Rubish::Context.singleton, context.parent
      assert_equal c1, context
      assert_equal "c1_out", context.o
      c2.eval {
        assert_equal c2, context
        assert_equal "c2_out", context.o
        assert_equal Rubish::Context.singleton, context.parent
      }
    }
  end
  
  should "use context specific workspace" do
    Helper.context.eval {
      assert_equal 1, foo1
      assert_equal 2, foo2
      cmd = ls
      assert_instance_of Rubish::Command, cmd
    }
  end

  should "use context specific IO" do
    output =  "context-output"
    c = Helper.context(nil,output)
    c.eval {
      
      assert_equal output, Rubish::Context.current.o
      cat.i { |p| p.puts 1}.exec
      assert_equal 1, cat.i(output).first.to_i
    }
  end

  should "set parent context when deriving" do
    c1 = Rubish::Context.singleton
    c11 = c1.derive
    c111 = c11.derive
    c12 = c1.derive
    c2 = Rubish::Context.new(Rubish::Workspace.new)

    assert_nil c1.parent
    assert_equal c1, c11.parent
    assert_equal c1, c12.parent
    assert_equal c11, c111.parent

    assert_nil c2.parent
    
    
  end

  should "derive context, using the context attributes of the original" do
    i1 = "i1"
    o1 = "o1"
    e1 = "e1"
    orig = Helper.context(i1, o1, e1)
    derived = orig.derive

    assert_not_equal orig, derived
    assert_equal orig.workspace, derived.workspace
    assert_equal orig.i, derived.i
    assert_equal orig.o, derived.o
    assert_equal orig.err, derived.err
    assert_not_equal orig.job_control, derived.job_control,  "derived context should have its own job control"

    # make changes to the derived context
    derived.i = "i2"
    derived.o = "o2"
    derived.err = "e2"

    derived.workspace = Rubish::Workspace.new.derive {
      def foo
        1
      end
    }
    assert_equal 1, derived.eval { foo }

    # orig should not have changed
    assert_equal i1, orig.i
    assert_equal o1, orig.o
    assert_equal e1, orig.err
    assert_instance_of Rubish::Command, orig.eval { foo }
    
  end

  should "use context specific job_controls" do
    rsh {
      jc1 = job_control
      slow = Helper.slowcat(1)
      j1 = slow.exec!

      jc2, j2 = nil 
      with {
        jc2 = job_control 
        j2 = slow.exec!
      }

      assert_not_equal jc1, jc2
      
      assert_equal [j1], jc1.jobs
      assert_equal [j2], jc2.jobs

      t = Helper.time_elapsed {
        jc1.waitall
        jc2.waitall
      }

      assert_in_delta 1, t, 0.1
      assert jc1.jobs.empty?
      assert jc2.jobs.empty?
    }
  end
  
end

class Rubish::Test::Job < TUT
  
  def setup
    setup_tmp
  end

  should "belong to job_control" do
    rsh {
      jc1 = job_control
      j1 = ls.exec!
      j2, jc2 = nil
      with {
        jc2 = job_control
      }

      assert_equal jc1, j1.job_control
      assert_not_equal jc2, j1.job_control
      
      assert_raise(Rubish::Error) {
        jc2.remove(j1)
      }
      
    }
  end

  should "set result to array of exit statuses" do
    rsh {
      ls.exec.each { |status|
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
    assert j1.done? && j2.done? && j3.done?
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
    assert j1.done? && j2.done? && j3.done?
    # each result should be an array of sized 3
    assert_equal 3, acc.size
  end

  should "wait for job" do
    job = Helper.slowcat(1).exec!
    assert_equal false, job.done?
    t = Helper.time_elapsed { job.wait }
    assert_in_delta 0.1, t, 1
    assert_equal true, job.done?
  end
  
  should "raise when waited twice" do
    assert_raise(Rubish::Error) {
      rsh {
        j = ls.exec!
        j.wait
        j.wait
      }
    }
  end

  should "kill a job" do
    acc = []
    j = Helper.slowcat(10).map!(acc)
    e = nil
    t = Helper.time_elapsed {
      sleep(2)
      begin
        j.stop!
      rescue
        e = $!
        assert_instance_of Rubish::Job::Failure, e
        assert_equal j, e.job
        assert_equal 1, j.bads.size
        assert_equal 0, j.goods.size
      end
    }
    assert_in_delta 2, acc.size, 1, "expects to get roughly two lines out before killing process"
    assert_in_delta 2, t, 0.1
    assert j.done?
    
    
    
  end
  
end


class Rubish::Test::JobControl < TUT

  should "use job control" do
    rsh {
      slow = Helper.slowcat(1).o "/dev/null"
      job1 = slow.exec!
      job2 = slow.exec!
      assert_kind_of Rubish::Job, job1
      assert_kind_of Rubish::Job, job2
      assert_equal 2, jobs.size
      assert_instance_of Array, jobs
      assert jobs.include?(job1)
      assert jobs.include?(job2)
      job1.wait
      job2.wait
      assert jobs.empty?, "expects jobs to empty"
    }
  end
  
  should "job control waitall" do
    rsh {
      puts "slowcat 1 * 3 lines in sequence"
      slow = Helper.slowcat(1)
      cats = (1..3).to_a.map { slow.exec! }
      assert_equal 3, jobs.size
      assert cats.all? { |cat| jobs.include?(cat) }
      t = Helper.time_elapsed { waitall }
      assert_in_delta 1, t, 0.1
      assert jobs.empty?
    }
  end

end


class Rubish::Test::Batch < TUT

  def setup
    setup_tmp
  end

  should "raise exception" do
    rsh {
      b = batch {
        1/0
      }
      j = nil
      assert_raise(Rubish::Job::Failure) {
        b.exec
      }
      assert jobs.empty?

      begin
        b.exec
      rescue Rubish::Job::Failure => e
        assert_instance_of ZeroDivisionError, e.reason
        assert_kind_of Rubish::Job, e.job
        j = e.job
        assert j.done?
        assert_nil j.result
        assert jobs.empty?
      end
      
      assert_raise(Rubish::Job::Failure) {
        j = b.exec!
        j.wait
      }
      assert j.done?
      assert_nil j.result
      assert jobs.empty?
    }
  end

  
  should "do batch as job" do
    rsh {
      b = batch {
        cat.i { |p| p.puts((1..10).to_a) }.exec
        cat.i { |p| p.puts((11..20).to_a) }.exec
        :result
      }

      rs = b.map { |i| i.to_i }
      assert jobs.empty?
      assert_equal (1..20).to_a, rs
      
      j1 = b.exec!
      assert_equal [j1], jobs
      j1.wait
      assert j1.done?
      assert_equal :result, j1.result
      assert jobs.empty?
    }
    
  end
  
  
  should "use context's IOs to execute in a batch" do
    rsh {
      b = batch {
        # use the contextual stdioe
        cat.i { |p| p.puts((1..10).to_a) }.exec
        # fix the output to bo2, only for this executable
        cat.i { |p| p.puts((100..110).to_a) }.o("bo2").exec
      }.o("bo1")
      
      b.exec
      assert jobs.empty?
      assert_equal (1..10).to_a, cat.i("bo1").map { |i| i.to_i }
      assert_equal (100..110).to_a, cat.i("bo2").map { |i| i.to_i }

      rm("*").exec
      b.o("bo3").exec
      assert jobs.empty?
      assert !File.exist?("bo1")
      assert_equal (1..10).to_a, cat.i("bo3").map { |i| i.to_i }
      assert_equal (100..110).to_a, cat.i("bo2").map { |i| i.to_i }
      
    }
    
  end
  
  should "be concurrent" do
    rsh {
      slow = Helper.slowcat(1)
      b = batch {
        slow.exec!
        slow.exec!
      }

      t = Helper.time_elapsed { b.exec }
      assert_in_delta 1, t, 0.2
      assert jobs.empty?

      j1, j2 = b.exec!, b.exec!
      assert_equal 2, jobs.size
      t = Helper.time_elapsed { waitall }
      assert j1.done?
      assert j2.done?
      assert jobs.empty?
    }
  end
  
end
