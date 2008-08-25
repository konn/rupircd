=begin
= rupircd -- Ruby Pseudo IRC Deamon

  ver 0.5b1 2007-05-18T22:30:56+09:00
  
  Copyright (c) 2007 konn <banzaida_at_jcom_dot_home_dot_ne_dot_jp>
  
  You can redistribute it and/or modify it under the same term as Ruby.
=end

$LOAD_PATH.unshift("./lib")
require "rupircd.rb"

if ARGV.empty?
  exit
end

conf = IRCd::FileConf.new(ARGV.shift)
serv = IRCd::IRCServer.new(conf)

Signal.trap('INT') do
  system("kill -9 #{$$}")
  serv.stop
end

serv.start