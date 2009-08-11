# Generated by jeweler
# DO NOT EDIT THIS FILE
# Instead, edit Jeweler::Tasks in Rakefile, and run `rake gemspec`
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rupircd}
  s.version = "0.6.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["konn"]
  s.date = %q{2009-08-12}
  s.description = %q{rupircd is a light IRC daemon written in 100% pure ruby.}
  s.email = %q{mr_konn[at]jcom[dot]home[dot]ne[dot]jp}
  s.executables = ["mkpassword", "rupircd"]
  s.extra_rdoc_files = [
    "Changes.ja.rd",
     "Changes.rd",
     "README.ja.rd",
     "README.rd",
     "Usage.ja.rd",
     "Usage.rd"
  ]
  s.files = [
    "Changes.ja.rd",
     "Changes.rd",
     "Manifest",
     "README.ja.rd",
     "README.rd",
     "Rakefile",
     "Usage.ja.rd",
     "Usage.rd",
     "VERSION",
     "bin/mkpassword",
     "bin/rupircd",
     "changes.html",
     "changes.ja.html",
     "index.html",
     "index.ja.html",
     "info.txt",
     "ircd.rb",
     "lib/rupircd.rb",
     "lib/rupircd/channel.rb",
     "lib/rupircd/charcode.rb",
     "lib/rupircd/conf.rb",
     "lib/rupircd/message.rb",
     "lib/rupircd/server.rb",
     "lib/rupircd/user.rb",
     "lib/rupircd/utils.rb",
     "mkpassword.rb",
     "motd.txt",
     "rupircd.gemspec",
     "sample.conf",
     "usage.html",
     "usage.ja.html"
  ]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/konn/rupircd}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{rupircd - RUby Pseudo IRC Daemon}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
