=begin
= rupircd -- Ruby Pseudo IRC Deamon

  ver 0.6 2009-08-11T23:45:52+09:00
  
  Copyright (c) 2008 Hiromi Ishii
  
  You can redistribute it and/or modify it under the same term as Ruby.


== What is this?
It is pseudo ircd written in Pure Ruby.
It has following special features.

* Using WEBrick
* Because of written in pure ruby, you can use it wherever ruby is installed.
  * You can use it without compiling
* It is light because it doesn't relay.
  * Features for relay are not implemented.
    * For example, "LINK" Command, "STATS m" Command
    * Channel having prefix '&' (Local Channel)
* Easy to configure!


And, it can't do following things, not to say I won't mount those things.

* Relaying with other server
  * Features about relaying
* Channel mask

It doesn't relay, so it's pseudo.


I modified and be using source "irc.rb" of Ruby Irc interfaCE "rice" as "message.rb".

Thanks.

== Target user
* Want to test your own bot without burdening the public server
* Want to setup IRC server for family circle
* Looking for light ircd
* Can't live without ruby!
* Fan of the developer(!?)

== USAGE
ruby ircd.rb sample.conf

If you would like to know more details, please read "USAGE.rd". (I will write it later :-P)
Well, anyway, Source must be the best Manual for this time, I think.

== TODO
(1) Think cooler name
(2) Implement all commands (whitout about Relaying) 
(3) Make installer
(4) Safe Channel
(5) "Service" client


== Thanks for
* rice (http://arika.org/ruby/rice)
* WEBrick
* ruby

and who would read this README weitten in terrible English by High School Student.

=end