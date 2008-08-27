=begin
= rupircd -- Ruby Pseudo IRC Deamon

  ver 0.5b2 2008-08-27T12:17:46+09:00
  
  Copyright (c) 2008 Hiromi Ishii
  
  You can redistribute it and/or modify it under the same term as Ruby.
=end

require 'webrick/server'
require 'monitor'
require 'thread'
require 'resolv'
require 'digest/md5'

require 'rupircd/channel.rb'
require 'rupircd/user'
require 'rupircd/utils.rb'
require 'rupircd/message.rb'
require 'rupircd/mykconv'
require 'rupircd/conf'

module IRCd
class IRCServer < WEBrick::GenericServer
  include Utils
  include Reply
  include Command

  include MonitorMixin

  def initialize(fconf, *args)
    @_init_args = [fconf, *args]
    @fconf = fconf
    super(fconf.load, *args)
    @used = Hash.new{|h, k| h[k.upcase] = [0,0,0]}
    init
  end

  def init
    @sockets = []
    @operators = []
    @channels = {}
    @users = {}
    @users.extend(MonitorMixin)
    @ping_threads = {}
    @ping_threads.extend(MonitorMixin)
    @old_nicks = Hash.new{|h, k| h[k] = []}
    config.replace(@fconf.load)
    cf = {}
    config[:Opers].each{|nick, pass|
      cf[mask_to_regex(nick)] = pass
    }
    config[:Opers].replace(cf)
  end

  def sock_from_nick(nick)
    if u = @users.find{|u, k| k.nick == nick}
      u[0]
    else
      nil
    end
  end
  
  def start_ping(sock)
    @ping_threads[sock] = Thread.new{
      sleep(config[:PINGInterval])
      send_client_message(sock, nil, PING, config[:ServerName])
      sleep(config[:PINGLimit])
      unregist(sock, "PING Timeout")
    }
  end
  
  def run(socket)
    socket.extend(MonitorMixin)
    user = nil
    nick = nil
    pass = nil
    begin
      first = true
      while line = socket.gets
        line.chomp!
        next if line.empty?
        case msg = Message.parse(line)
        when PASS
          if first
            pass = msg.params[-1]
            first = false
          else
          end
        when USER
          user = msg.params
          if msg.params.size < 4
            socket.puts err_needmoreparams(msg.command, "Not enough parameters")
            user = nil
          end
        when NICK
          nick = msg.params[0]
          if @users.values.any?{|us| us.nick == nick}
            socket.puts ERR_NICKNAMEINUSE.new(config[:ServerName], "433", [nick, "Nickname is already in use"])
            nick = nil
          else
          end
        end
        break if nick && user
      end
    end
    return unless nick && user
    start_ping(socket)
    @sockets << socket
    begin
      host = Resolv.getname(socket.addr[-1])
    rescue
      host = socket.addr[-1]
    end
    user = User.new(nick, "~"+user[0].split("@")[0], host, user[-1], user[1])
    @old_nicks[nick].unshift user.to_a
    @users[socket] = user
    send_server_message(socket, "001", "Welcome to the Internet Relay Network #{user}")
    send_server_message(socket, "002", "Your host is #{config[:ServerName]}, running version 0.1b")
    send_server_message(socket, "003", "This server was created #{Time.now}")
    send_server_message(socket, "004", "#{config[:ServerName]} 0.1b aiwroOs oavimnqsrtklObeI")
    print_motd(socket)
    while !socket.closed? && line = socket.gets
      recv_message(socket, line)
    end
    unregist(socket)
  end

  def unregist(socket, msg="EOF From client")
    synchronize do
      @sockets.delete(socket)
      @ping_threads[socket].kill if @ping_threads.has_key?(socket)
      sended = []
      if @users.include?(socket)
        @users[socket].joined_channels.each{|chname|
          ch = @channels[chname]
          ch.unregist(socket)
          ch.members.each{|mem|
            unless sended.include?(mem)
              begin
                sended.push mem
                mem.puts QUIT.new(@users[socket].to_s, "QUIT", [msg])
              rescue
                next
              end
            end
          }
          @channels.delete(chname) if ch.members.empty?
        }
        @users.delete(socket)
      end
    end
    socket.close unless socket.closed?
  end

  def print_motd(sock)
    send_server_message(sock, "375", "- #{config[:ServerName]} Message of the day - ")
    config[:Motd].each_line{|line|
      line.chomp!
      send_server_message(sock, "372", "- " + line)
    }
    send_server_message(sock, "376", "End of MOTD command")
  end

  def oper_proc(sock, &pr)
    usr = @users[sock]
    if usr.operator || usr.local_operator
      pr.call(sock)
    else
      send_server_message(sock, "481", "Permission Denied - You're not an IRC operator")
    end
  end

  def recv_message(sock, line)
    line.chomp!
    return if line.empty?
    begin
      msg = Message.parse(line)
      params = msg.params
      @used[msg.command.upcase][0] += 1
      case msg
      when MOTD
        print_motd(sock)
      when LUSERS
        send_server_message(sock, "251", "There are #{@users.size} users and 0 services on 1 servers")
        unless @operators.empty?
          send_server_message(sock, "252", @operators.size, "operator(s) online")
        end
        unless @channels.empty?
          send_server_message(sock, "254", @channels.size, "channels formed")
        end
        send_server_message(sock, "255", "I have #{@users.size} clients and 0 servers")
      when OPER
        raise NotEnoughParameter if params.size < 2
        nick, pass = params
        unless opdic = config[:Opers].find{|k, v| k =~ nick}
          send_server_message(sock, "491", "No O-lines for your host")
          return
        end
        if Digest::MD5.hexdigest(pass) == opdic[1]
          @users[sock].operator = true
          @users[sock].local_operator = true
          @operators.push sock
          send_server_message(sock, "381", "You are now an IRC operator")
        else
          send_server_message(sock, "464", "Password incorrect")
        end
      when CLOSE
        @users.synchronize do
          oper_proc(sock) do
            @sockets.each{|s| unregist(s) }
          end
        end
      when DIE
        oper_proc(sock) do
          shutdown
          exit!
        end
      when REHASH
        oper_proc(sock) do |sck|
          cnf = @fconf.load
          if Hash === cnf
            config.replace(cnf)
            send_server_message(sck, "382", "#{@fconf.path} :Rehashing")
          else
            raise "Invalid Conf file"
          end
        end
      when RESTART
        oper_proc(sock) do |sck|
          @sockets.each{|s| unregist(s) }
          init
        end
      when VERSION
        send_server_message(sock, "351", "rupircd-01b.0 #{config[:ServerName]} :Ruby Pseudo IRCD 0.1b")
      when STATS
        if params.empty?
          raise NotEnoughParameter
          return
        end
        c = params[0][0]
        case c
        when ?l
          
        when ?m
          @used.each_pair{|cmd, val|
            send_server_message(sock, "212", cmd, val)
          }
        when ?o
          
        when ?u
          vs = Time.now.to_i - @started.to_i
          days = vs / (3600*24)
          vs -= days * 3600 * 24
          hours = vs / 3600
          vs -= hours * 3600
          minutes = vs/60
          vs -= minutes * 60
          send_server_message(sock, "242", format("Server Up %d days %d:%02d:%02d",days,hours,minutes,vs))
        end
        send_server_message(sock, "219", c.chr, "End of STATS report")
      when JOIN
        if params[0] == "0"
          @users[sock].joined_channels.each{|ch|
            @channels[ch].part(sock, "")
          }
          @users[sock].joined_channels = []
        else
          chs = params[0].split(",")
          keys = msg.params[1].split(",") if params.size >= 2
          keys ||= []
          chs.each_with_index{|ch, i|
            unless channame?(ch)
              send_server_message(sock, "403", ch, "No such channel")
              next
            end
            
            chclass = case ch
            when /^\+/
              NoModeChannel
            when /^#/
              Channel
            when /^!#/
              SafeChannel
            end
            unless @channels.has_key?(ch)
              @channels[ch] = chclass.new(self, sock, ch)
              handle_reply(sock, @channels[ch].join(sock, keys[i]))
            else
              rpl = @channels[ch].join(sock, keys[i])
              handle_reply(sock, rpl)
            end
          }
        end
      when PART
        ch, msg = params
        msg ||= ""
        chs = ch.split(",")
        chs.each{|ch|
          @channels[ch].part(sock, msg)
          if @channels[ch].members.empty?
            @channels.delete(ch)
          end
          @users[sock].joined_channels.delete(ch)
        }
      when PING
        send_client_message(sock, config[:ServerName], PONG, config[:ServerName], *params)
      when INFO
        config[:Info].each_line{|line|
          line.chomp!
          line.tojis!
          send_server_message(sock, "371", line)
        }
        send_server_message(sock, "374", "End of INFO list")
      when LINKS
        send_server_message(sock, "365")
      when TIME
        send_server_message(sock, "391", config[:ServerName], Time.now.to_s)
      when PONG
        @ping_threads[sock].kill
        start_ping(sock)
      when INVITE
        if params.size < 2
          raise NotEnoughParameter
        else
          who, to = params
          if tmp = @users.find{|k, v| v.nick == who}
            s, usr = tmp
            if usr.away?
              msg = usr.away
              send_server_message(sock, "301", who, msg)
              return
            end
            if ch = @channels[to]
              handle_reply(sock, ch.invite(sock, s))
            else
              send_server_message(sock, "401", who, "No such nick/channel")
            end
          else
            send_server_message(sock, "401", who, "No such nick/channel")
          end
        end
      when LIST
        if params.empty?
          chs = @channels.find_all{|k, v| v.visible?(nil)}
          chs.each{|k, v|
            case (tpc = v.get_topic(sock, true))[0]
            when "331"
              tpc = ""
            else
              tpc = tpc[-1]
            end
            send_server_message(sock, "322", k, v.members.size.to_s, tpc)
          }
        else
          chs = params[0].split(",").find_all{|name| @channels[name] && @channels[name].visible?(sock)}
          chs.each{|k|
            v = @channels[k]
            uss = v.members.find_all{|m| !@users[m].invisible}
            case (tpc = v.get_topic(sock, true))[0]
            when "331"
              tpc = ""
            else
              tpc = tpc[-1]
            end
            send_server_message(sock, "322", k, v.members.size.to_s, tpc)
          }
        end
        send_server_message(sock, "323", "End of LIST")
      when TOPIC
        chn, topic = params
        unless ch = @channels[chn]
          send_server_message(sock, "403", chn, "No such channel")
          return
        end
        if params.size < 1
          raise NotEnoughParameter
        elsif params.size == 1
          
          send_server_message(sock, *ch.get_topic(sock))
        else
          handle_reply(sock, ch.set_topic(sock, topic))
        end
      when PRIVMSG
        if params.size < 2
          raise NotEnoughParameter
        end
        to, msg = params
        if ch = @channels[to]
          if msg.empty?
            send_server_message(sock, "412", "No text to send")
          else
            handle_reply(sock, ch.privmsg(sock, msg))
          end
        elsif who = @users.find{|k, v| v.nick == to}
          if who[1].away?
            away = who[1].away
            send_server_message(sock, "301", to, away)
          else
            send_client_message(who[0], @users[sock], PRIVMSG, who[1].nick, msg)
          end
        else
          send_server_message(sock, "401", to, "No such nick/channel")
        end
      when NAMES
        if params.size < 1
          raise NotEnoughParameter
        else
          chs = params[0].split(",")
          chs.each{|ch|
            handle_reply(sock, @channels[ch].names(sock))
          }
        end
      when NOTICE
        if params.size < 2
          raise NotEnoughParameter
          return
        end
        to, msg = params
        if ch = @channels[to]
          if msg.empty?
            send_server_message(sock, "412", "No text to send")
          else
            handle_reply(sock, ch.notice(sock, msg))
          end
        elsif who = @users.find{|k, v| v.nick == to}
          send_client_message(who[0], @users[sock], NOTICE, who[1].nick, msg)
        else
          send_server_message(sock, "401", to, "No such nick/channel")
        end
      when AWAY
        if params.empty? || params[0].empty?
          @users[sock].away = ""
          send_server_message(sock, "305", "You are no longer marked as being away")
        else
          @users[sock].away = params.shift
          send_server_message(sock, "306", "You have been marked as being away")
        end
      when MODE
        if params.size < 1
          raise NotEnoughParameter
          return
        end
        to = params.shift
        #p @channels
        if ch = @channels[to]
          handle_reply(sock, ch.handle_mode(sock, params))
        elsif who = @users.find{|k, v| v.nick == to}
          if who[0] == sock
            if params.empty?
              send_server_message(sock, "221", who[1].get_mode_flags)
            else
              rls = who[1].set_flags(params[0])
              usr = @users[sock]
              send_client_message(sock, usr, MODE, usr.nick, rls.join(" "))
            end
          else
            send_server_message(sock, "502", "Cannot change mode for other users")
          end
        else
          send_server_message(sock, "401", to, "No such nick/channel")
        end
      when NICK
        if params.empty?
          send_server_message(sock, "431", "No nickname given")
        else
          user = @users[sock]
          nick = params[0]
          if nick == "0"
            nick = user.identifier.to_s
          elsif !correct_nick?(nick)
            send_server_message(sock, "432", nick, "Erroneous nickname")
            return
          end
          if @users.any?{|s, us| us.nick == nick}
            send_server_message(sock, "433", nick, "Nickname is already in use")
          elsif user.restriction
            send_server_message(sock, "484", "Your connection is restricted!")
          else
            send_client_message(sock, user, NICK, nick)
            sended = []
            user.joined_channels.each{|ch|
              ch = @channels[ch]
              ch.members.each{|mem|
                if !sended.include?(mem) && mem != sock
                  sended << mem
                  send_client_message(mem, user, NICK, nick)
                end
              }
            }
            @old_nicks[nick].unshift user.to_a
            user.nick = nick
          end
        end
      when WHOIS
        raise NotEnoughParameter if params.empty?
        params[0].split(",").each{|mask|
          reg = mask_to_regex(mask)
          matched = @users.find_all{|s, usr| usr.nick =~ reg}
          if matched.empty?
            send_server_message(sock, "401", mask, "No such nick/channel")
          else
            matched.each{|sc, user|
              send_server_message(sock, "311", user.nick, user.user, user.host, "*", user.real)
              send_server_message(sock, "312", user.nick, config[:ServerName], "this server.")
              send_server_message(sock, "313", user.nick, "is an IRC operator") if @operators.include?(sc)
              chs = []
              user.joined_channels.each{|ch|
                ch = @channels[ch]
                if ch.visible?(sock)
                  pr = ""
                  if ch.mode.op?(sc)
                    pr = "@"
                  else ch.mode.voiced?(sc)
                    pr = "+"
                  end
                  chs << pr+ch.name
                end
              }
              send_server_message(sock, "319", user.nick, chs.join(" "))
              if user.away?
                away = user.away
                send_server_message(sock, "301", user.nick, away)
              end
              send_server_message(sock, "318", user.nick, "End of WHOIS list")
            }
          end
        }
      when WHOWAS
        raise NotEnoughParameter if params.empty?
        params[0].split(",").each{|nick|
          if @users.any?{|s, us| us.nick == nick}
            send_server_message(sock, "312", nick, config[:ServerName], "this server.")
          elsif @old_nicks[nick].empty?
            send_server_message(sock, "406", nick, "There was no such nickname")
          else
            @old_nicks[nick].each{|nms|
              send_server_message(sock, "314", *nms)
            }
          end
          send_server_message(sock, "369", nick, "End of WHOWAS")
        }
      when WHO
        raise NotEnoughParameter if params.empty?
        mask = mask_to_regex(params[0])
        chs = @channels.find_all{|name, ch| name =~ mask && ch.visible?(sock)}
        unless chs.empty?
          chs.each{|name, ch|
            ch.members.each{|sck|
              usr = @users[sck]
              nick, user, host, _, real = usr.to_a
              sym = usr.away? ? "G" : "H"
              sym += @operators.include?(sck) ? "*" : ""
              sym += ch.mode.op?(sck) ? "@" : (ch.mode.voiced?(sck) ? "+" : "")
              send_server_message(sock, "352", name, user, host, config[:ServerName], nick, sym, "0 #{real}")
            }
            send_server_message(sock, "315", name, "End of WHO list")
          }
        else
          usrs = @users.find_all{|sock, us| us.nick =~ mask || us.user =~ mask || us.host =~ mask}
          usrs.each{|sk,usr|
            send_server_message(sock, "352", "*", usr.user, usr.host, config[:ServerName], usr.nick, "H", "0 #{usr.real}")
            send_server_message(sock, "315", usr.nick, "End of WHO list")
          }
        end
      when KICK
        raise NotEnoughParameter if params.size < 2
        chs = params[0].split(",")
        whos = params[1].split(",")
        msg = params[2].to_s
        if chs.size == 1
          if ch = @channels[chs[0]]
            whos.each{|who|
              if usr = @users.find{|s, us|us.nick==who}
                handle_reply sock, ch.kick(usr[0], sock, msg)
              else
                send_server_message(sock, "401", who, "No such nick/channel")
              end
            }
          else
            send_server_message(sock, "403", chs[0], "No such channel")
          end
        elsif chs.size == whos.size
          chs.each_with_index{|chn, i|
            if chn = @channels[chn]
              if usr = @users[whos[i]]
                handle_reply sock, ch.kick(usr, sock, msg)
              else
                send_server_message(sock, "401", whos[i], "No such nick/channel")
              end
            else
              send_server_message(sock, "403", chn, "No such channel")
            end
          }
        end
      when ISON
        raise NotEnoughParameter if params.empty?
        a = params.find_all{|nick| @users.any?{|dum, us| us.nick == nick}}
        send_server_message(sock, "303", a.join(" "))
      when USERHOST
        raise NotEnoughParameter if params.empty?
        hoge = params[0..4]
        hoge.map!{|nick|
          if h = @users.find{|s, u| u.nick == nick}
            s, u = h
            suf = @operators.include?(s) ? "*" : ""
            pre = u.away? ? "-" : "+"
            usr = u.user
            host = u.host
            nick + suf + "=" + pre + usr + "@" + host + " "
          else
            ""
          end
        }
        send_server_message(sock, "302", hoge.join(" "))
      when QUIT
        user = @users[sock]
        send_client_message(sock, nil, ERROR, "Closing", "Link:", "#{user.nick}[#{user.user}@#{user.host}]", %Q!("#{params[0]}")!)
        unregist(sock, params[0])
      else
        raise UnknownCommand.new(msg.command)
      end
    rescue NotEnoughParameter => e
      send_server_message(sock, "461", msg.command, "Not enough parameters")
    rescue UnknownCommand => e
      send_server_message(sock, "421", e.cmd, "Unknown command")
    rescue
      puts $!, $@
    end
  end

  def handle_reply(sock, rpl)
    return unless rpl
    case rpl[0]
    when Array
      rpl.each{|rp|
        handle_reply(sock, rp)
      }
    when Command
      send_client_message(sock, @users[sock], *rpl)
    else
      send_server_message(sock, *rpl)
    end
  end

  def send_message(sock, user, msg, *args)
    case msg
    when Command
      send_client_message(sock, user, msg, *args)
    when Reply
      send_server_message(sock, msg, *args)
    end
  end

  def send_client_message(sock, user, cmd, *args)
    if sock.closed?
      unregist(sock)
      return
    end
    msg = cmd.new(user.to_s, cmd.name.split('::').last, args)
    sock.puts msg
  end

  def send_server_message(sock, msg, *args)
    if sock.closed?
      unregist(sock)
      return
    end
    args.unshift @users[sock].nick
    sock.puts Message.build(config[:ServerName], msg, args)
  end

  def get_user(sock)
    @users.fetch(sock){unregist(sock, "Conenction reset by peer")}
  end

  def start(*args)
    @started = Time.now
    super
  end

end
end