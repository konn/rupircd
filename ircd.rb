=begin
= rupircd -- Ruby Pseudo IRC Deamon

  ver 0.6.3 2009-08-12T22:52:27+09:00
  
  Copyright (c) 2007 konn <banzaida_at_jcom_dot_home_dot_ne_dot_jp>
  
  You can redistribute it and/or modify it under the same term as Ruby.
=end

$LOAD_PATH.unshift("./lib")
require "rupircd"

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