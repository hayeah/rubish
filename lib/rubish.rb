$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'pp'
require 'fileutils'
require 'readline'
require 'irb/input-method'
require 'irb/ruby-lex'

require 'rubish/stub'
require 'rubish/job_control'
require 'rubish/executable'
require 'rubish/command'
require 'rubish/command_builder'
require 'rubish/pipe'
require 'rubish/streamer'
require 'rubish/sed'
require 'rubish/awk'
require 'rubish/session'
