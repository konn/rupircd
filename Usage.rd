=begin
= Usage
== Start up
To start up server on 6667, to execute this command: 
 $ ruby ircd.rb [Configuration File(e.g. sample.conf)]

It might shut down when it received ^C (SIGINT).

== How to write configuration file
Contents of sample.conf might be like this:

 Conf = {
   :Motd => open("motd.txt"){|f| f.read }.tojis,
   :Info => open("info.txt"){|f| f.read }.tojis,
   :Port => 6667,
   :Opers => {"superoper*"=>"ea703e7aa1efda0064eaa507d9e8ab7e"},
   :MaxClients => 100,
   :PINGInterval => 300,
   :PINGLimit => 90,
 }

As you can see, its contents is written in Ruby Hash Object.
To configure, write like this;
 　
 :name => value, 
 
between "{" and "}" .

For now, you can configure these items: 
::Motd
  Set down the paragraph shown first when user connected to Server.  It's good to write the information, greetings, your poem, line-shoot, bla bla bla...
  In sample.conf, it is set to contents of "info.txt".
::Info
  Set down the paragraph for answer to INFO command.
  It's good to write server's information or history.
  In sample.conf, it is set to contents of "info.txt".
::Port
  The port server will be running on. Please select unused port. (recommended: 6660 ~ 6669).
  In sample.conf, it is set to 6667.
::Opers
  Hash of password and the mask of server operator's name.
  To know more detail, read "((How to use OPER))".
::MaxClients
  Number of the clients which can connect to server in same time.
  In sample.conf, it is set to 100.
::PINGInterval
  Interval of time to ping (sec).
  After some seconds(set down in :PINGLimit) server send to PING, server disconnect the clients if clients doesn't respond PONG.
  In sample.conf, it's set to 300sec.
::PINGLimit
  Seconds the server wait for PONG message from clients after server sent PING. 
  In sample.conf, it's set to 90 seconds.

I will add items when in the mood.

= How to use OPER
== Configuration
Oper means Server Operator. It is user who has the authority to restart, stop  and rehash server.

To become an Oper requires the pair of correct OPER nick name and password. Conversely, anybody can become an Oper if he/she knows those.
To get authority of Oper, you have to send OPER message to the server.
For example, if Oper nick name is oper and password is foo, to send this:
  OPER oper1 hoge
to be an Oper.


You can set these combination in the configuration file. Like this:
  :Opers => {OPER1 => pass1, OPER2 => pass2, ...},

For example, in sample.conf:
  :Opers => {"superoper*" => "ea703e7aa1efda0064eaa507d9e8ab7e"},
In this case, relate Oper name starts from "superoper" and password "hoge".

Password is encrypted by MD5. To know the MD5-value for any password, use included program "mkpassword.rb" :
  $ ruby mkpassword.rb password

== Available commands on Oper
:REHASH
  Reload the configuration file.
:CLOSE
  Close the connection between all clients and the server.
:RESTART
  Restart the server.
:DIE
  Shut down the server.
=end