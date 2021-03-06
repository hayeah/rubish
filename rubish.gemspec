# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rubish}
  s.version = "0.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Howard Yeh"]
  s.date = %q{2010-01-20}
  s.default_executable = %q{rubish}
  s.description = %q{Ruby Interactive Shell}
  s.email = %q{hayeah@gmail.com}
  s.executables = ["rubish"]
  s.extra_rdoc_files = [
    "LICENSE"
  ]
  s.files = [
    "LICENSE",
     "README.markdown",
     "README.textile",
     "Rakefile",
     "VERSION.yml",
     "bin/rubish",
     "lib/rubish.rb",
     "lib/rubish/awk.rb",
     "lib/rubish/batch_executable.rb",
     "lib/rubish/command.rb",
     "lib/rubish/command_builder.rb",
     "lib/rubish/context.rb",
     "lib/rubish/executable.rb",
     "lib/rubish/job.rb",
     "lib/rubish/job_control.rb",
     "lib/rubish/pipe.rb",
     "lib/rubish/repl.rb",
     "lib/rubish/sed.rb",
     "lib/rubish/streamer.rb",
     "lib/rubish/stub.rb",
     "lib/rubish/unix_executable.rb",
     "lib/rubish/workspace.rb",
     "test/slowcat.rb",
     "test/test.rb",
     "test/test_dev.rb"
  ]
  s.homepage = %q{http://github.com/hayeah/rubish}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Ruby Interactive Shell}
  s.test_files = [
    "test/test.rb",
     "test/test_dev.rb",
     "test/slowcat.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end

