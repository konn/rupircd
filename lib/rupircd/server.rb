=begin
= rupircd -- Ruby Pseudo IRC Deamon

  ver 0.6 2009-08-11T23:45:52+09:00
  
  Copyright (c) 2009 Hiromi Ishii
  
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
require 'rupircd/charcode'
require 'rupircd/conf'

module IRCd
  VERSION = "0.6.2"

class IRCServer < WEBrick::GenericServer
  include Utils
  include Reply
  include Command

  include MonitorMixin

  class <<self
    def define_oper_command(mtd, &pr)
      define_method(mtd){|usr, param|
        if usr.operator || usr.local_operator
          instance_eval(&pr)
        else
          send_server_message(usr, "481", "Permission Denied - You're not an IRC operator")
        end
      }
    end
  end


  def initialize(fconf, *args)
    @_init_args = [fconf, *args]
    @fconf = fconf
    super(fconf.load, *args)
    @used = Hash.new{|h, k| h[k.upcase] = [0,0,0]}
    init
  end

  def init
    @operators = []
    @channels = {}
    @users = []
    @users.extend(MonitorMixin)
    @ping_threads = {}
    @ping_threads.extend(MonitorMixin)
    @old_nicks = Hash.new{|h, k| h[k] = []}
    config.replace(@fconf.load)
    cf = {}
    config.fetch(:Opers,{}).each{|nick, pass|
      cf[mask_to_regex(nick)] = pass
    }
    config[:Opers] = cf
    config[:ServerName] = "127.0.0.1"
  end

  def user_from_nick(nick)
    u = @users.find{|u| u.nick == nick}
  end
  
  def start_ping(user)
    @ping_threads[user] = Thread.new{
      sleep(config[:PINGInterval])
      send_client_message(user, nil, PING, config[:ServerName])
      sleep(config[:PINGLimit])
      unregister(user, "PING Timeout")
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
          if us = @users.find{|us| us.nick == nick}
            socket.puts ERR_NICKNAMEINUSE.new(config[:ServerName], "433", [nick, "Nickname is already in use"])
            nick = nil
          else
          end
        end
        break if nick && user
      end
    end
    return unless nick && user
    start_ping(user)
    begin
      host = Resolv.getname(socket.addr[-1])
    rescue
      host = socket.addr[-1]
    end
    user = User.new(nick, "~"+user[0].split("@")[0], host, user[-1], socket, user[1])
    @old_nicks[nick].unshift user.to_a
    @users << user
    send_server_message(user, "001", "Welcome to the Internet Relay Network #{user}")
    send_server_message(user, "002", "Your host is #{config[:ServerName]}, running version 0.1b")
    send_server_message(user, "003", "This server was created #{Time.now}")
    send_server_message(user, "004", "#{config[:ServerName]} 0.1b aiwroOs oavimnqsrtklObeI")
    print_motd(user)
    while !socket.closed? && line = socket.gets
      recv_message(user, line)
    end
    unregister(user)
  end

  def unregister(user, msg="EOF From client")
    synchronize do
      socket = user.socket
      @ping_threads[user].kill if @ping_threads.has_key?(socket)
      sent = []
      if @users.include?(user)
        user.joined_channels.each{|ch|
          ch.unregister(user)
          ch.members.each{|mem|
            unless sent.include?(mem)
                sent << mem
                send_client_message(mem, user, QUIT, msg)
            end
          }
          @channels.reject!{|k,v|v==ch} if ch.members.empty?
        }
        @users.delete(user)
      end
    end
    user.socket.close unless user.socket.closed?
  end

  def recv_message(user, line)
    line.chomp!
    return if line.empty?
    begin
      msg = Message.parse(line)
      params = msg.params
      @used[msg.command.upcase][0] += 1
      mtd = "on_" + msg.command.downcase
      if respond_to?(mtd)
        __send__(mtd, user, params)
      else
        raise UnknownCommand.new(msg.command)
      end
    rescue NotEnoughParameter => e
      send_server_message(user, "461", msg.command, "Not enough parameters")
    rescue UnknownCommand => e
      send_server_message(user, "421", e.cmd, "Unknown command")
    rescue
      puts $!, $@
    end
  end

  def on_motd(user, params)
    print_motd(user)
  end

  def print_motd(user)
    send_server_message(user, "375", "- #{config[:ServerName]} Message of the day - ")
    config[:Motd].each_line{|line|
      line.chomp!
      send_server_message(user, "372", "- " + line)
    }
    send_server_message(user, "376", "End of MOTD command")
  end

  def on_lusers(user, params)
    send_server_message(user, "251", "There are #{@users.size} users and 0 services on 1 servers")
    unless @operators.empty?
      send_server_message(user, "252", @operators.size, "operator(s) online")
    end
    unless @channels.empty?
      send_server_message(user, "254", @channels.size, "channels formed")
    end
    send_server_message(user, "255", "I have #{@users.size} clients and 0 servers")
  end
  
  def on_oper(user, params)
    raise NotEnoughParameter if params.size < 2
    nick, pass = params
    unless opdic = config.fetch(:Opers,{}).find{|k, v| k =~ nick}
      send_server_message(user, "491", "No O-lines for your host")
      return
    end
    if Digest::MD5.hexdigest(pass) == opdic[1]
      user.operator = true
      user.local_operator = true
      @operators.push user
      send_server_message(user, "381", "You are now an IRC operator")
    else
      send_server_message(user, "464", "Password incorrect")
    end
  end

  define_oper_command :on_close do |user, params|
    @users.synchronize do
      @users.each{|s| unregister(s) }
    end
  end
  
  define_oper_command :on_die do |usr, params|
    shutdown
    exit!
  end
  
  define_oper_command :on_rehash do |usr, params|
    cnf = @fconf.load
    
    if Hash === cnf
      config.replace(cnf)
      send_server_message(usr, "382", "#{@fconf.path} :Rehashing")
    else
      raise "Invalid Conf file"
    end
  end

  define_oper_command :on_restart do |usr, params|
    @users.each{|s| unregister(s) }
    init
  end

  def on_version(user, params)
    send_server_message(user, "351", "rupircd-#{VERSION} #{config[:ServerName]} :Ruby Pseudo IRCD 0.1b")
  end

  def on_stats(user, params)
    if params.empty?
      raise NotEnoughParameter
      return
    end
    c = params[0][0]
    case c
    when ?l
      
    when ?m
      @used.each_pair{|cmd, val|
        send_server_message(user, "212", cmd, val[0])
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
      send_server_message(user, "242", format("Server Up %d days %d:%02d:%02d",days,hours,minutes,vs))
    end
    send_server_message(user, "219", c.chr, "End of STATS report")
  end

  def on_join(user, params)
    if params[0] == "0"
      user.joined_channels.each{|ch|
        channel(ch).part(user, "")
      }
      user.joined_channels = []
    else
      chs = params[0].split(",")
      keys = params[1].split(",") if params.size >= 2
      keys ||= []
      chs.each_with_index{|ch, i|
        unless channame?(ch)
          send_server_message(user, "403", ch, "No such channel")
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
        unless @channels.has_key?(ch.downcase)
          set_channel(ch, chclass.new(self, user, ch) )
          handle_reply(user, channel(ch).join(user, keys[i]))
        else
          rpl = channel(ch).join(user, keys[i])
          handle_reply(user, rpl)
        end
      }
    end
  end

  def on_part(user, params)
    ch, msg = params
    msg ||= ""
    chs = ch.split(",")
    chs.each{|chname|
      ch = channel(chname)
      ch.part(user, msg)
      if ch.members.empty?
        @channels.delete(chname.downcase)
      end
      user.joined_channels.delete(ch)
    }
  end

  def on_ping(user, params)
    send_client_message(user, config[:ServerName], PONG, config[:ServerName], *params)
  end

  def on_info(user, params)
    config[:Info].each_line{|line|
      line.chomp!
      send_server_message(user, "371", line)
    }
    send_server_message(user, "374", "End of INFO list")
  end

  def on_links(user, params)
    send_server_message(user, "365")
  end

  def on_time(user, params)
    send_server_message(user, "391", config[:ServerName], Time.now.to_s)
  end

  def on_pong(user, params)
    @ping_threads[user].kill
    start_ping(user)
  end

  def on_invite(user, params)
    if params.size < 2
      raise NotEnoughParameter
    else
      who, to = params
      if target = @users.find{|v| v.nick == who}
        if target.away?
          msg = target.away
          send_server_message(user, "301", who, msg)
          return
        end
        if ch = channel(to)
          handle_reply(user, ch.invite(user, target))
        else
          send_server_message(user, "401", who, "No such nick/channel")
        end
      else
        send_server_message(user, "401", who, "No such nick/channel")
      end
    end
  end

  def on_list(user, params)
    if params.empty?
      chs = @channels.find_all{|k, v| v.visible?(nil)}
      chs.each{|k, v|
        case (tpc = v.get_topic(user, true))[0]
        when "331"
          tpc = ""
        else
          tpc = tpc[-1]
        end
        send_server_message(user, "322", k, v.members.size.to_s, tpc)
      }
    else
      chs = params[0].split(",").find_all{|name| channel(name) && channel(n).visible?(user)}
      chs.each{|k|
        v = channel(k)
        uss = v.members.find_all{|m| !m.invisible}
        case (tpc = v.get_topic(user, true))[0]
        when "331"
          tpc = ""
        else
          tpc = tpc[-1]
        end
        send_server_message(user, "322", k, v.members.size.to_s, tpc)
      }
    end
    send_server_message(user, "323", "End of LIST")
  end

  def on_topic(user, params)
    chn, topic = params
    unless ch = channel(chn)
      send_server_message(user, "403", chn, "No such channel")
      return
    end
    if params.size < 1
      raise NotEnoughParameter
    elsif params.size == 1
      send_server_message(user, *ch.get_topic(user))
    else
      handle_reply(user, ch.set_topic(user, topic))
    end
  end

  def on_privmsg(user, params)
    if params.size < 2
      raise NotEnoughParameter
    end
    to, msg = params
    if ch = channel(to)
      if msg.empty?
        send_server_message(user, "412", "No text to send")
      else
        handle_reply(user, ch.privmsg(user, msg))
      end
    elsif who = @users.find{|v| v.nick == to}
      if who.away?
        away = who.away
        send_server_message(user, "301", to, away)
      else
        send_client_message(who, user, PRIVMSG, who.nick, msg)
      end
    else
      send_server_message(user, "401", to, "No such nick/channel")
    end
  end

  def on_names(user, params)
    if params.size < 1
      raise NotEnoughParameter
    else
      chs = params[0].split(",")
      chs.each{|ch|
        handle_reply(user, channel(ch).names(user))
      }
    end
  end

  def on_notice(user, params)
    if params.size < 2
      raise NotEnoughParameter
      return
    end
    to, msg = params
    if ch = channel(to)
      if msg.empty?
        send_server_message(user, "412", "No text to send")
      else
        handle_reply(user, ch.notice(user, msg))
      end
    elsif who = @users.find{|v| v.nick == to}
      send_client_message(who, user, NOTICE, user.nick, msg)
    else
      send_server_message(user, "401", to, "No such nick/channel")
    end
  end

  def on_away(user, params)
    if params.empty? || params[0].empty?
      user.away = ""
      send_server_message(user, "305", "You are no longer marked as being away")
    else
      user.away = params.shift
      send_server_message(user, "306", "You have been marked as being away")
    end
  end

  def on_mode(user, params)
    if params.size < 1
      raise NotEnoughParameter
      return
    end
    to = params.shift
    if ch = channel(to)
      handle_reply(user, ch.handle_mode(user, params))
    elsif who = @users.find{|v| v.nick == to}
      if who == user
        if params.empty?
          send_server_message(user, "221", who.get_mode_flags)
        else
          rls = who.set_flags(params[0])
          send_client_message(user, user, MODE, user.nick, rls.join(" "))
        end
      else
        send_server_message(user, "502", "Cannot change mode for other users")
      end
    else
      send_server_message(user, "401", to, "No such nick/channel")
    end
  end

  def on_nick(user, params)
    if params.empty?
      send_server_message(user, "431", "No nickname given")
    else
      nick = params[0]
      if nick == "0"
        nick = user.identifier.to_s
      elsif !correct_nick?(nick)
        send_server_message(user, "432", nick, "Erroneous nickname")
        return
      end
      if us = user_from_nick(nick)
        return if us == user
        send_server_message(user, "433", nick, "Nickname is already in use")
      elsif user.restriction
        send_server_message(user, "484", "Your connection is restricted!")
      else
        send_client_message(user, user, NICK, nick)
        sent = []
        user.joined_channels.each{|ch|
          ch.members.each{|mem|
            if !sent.include?(mem) && mem != user
              sent << mem
              send_client_message(mem, user, NICK, nick)
            end
          }
        }
        @old_nicks[nick].unshift user.to_a
        user.nick = nick
      end
    end
  end

  def on_user(user, params)
    puts_socket(user, ERR_ALREADYREGISTRED.new(config[:ServerName], "462", [user.nick, "Unauthorized command (already registered)"]))
  end
  
  def on_pass(user, params)
    puts_socket(user, ERR_ALREADYREGISTRED.new(config[:ServerName], "462", [user.nick, "Unauthorized command (already registered)"]))
  end
  
  def on_whois(user, params)
    raise NotEnoughParameter if params.empty?
    params[0].split(",").each{|mask|
      reg = mask_to_regex(mask)
      matched = @users.find_all{|usr| usr.nick =~ reg}
      if matched.empty?
        send_server_message(user, "401", mask, "No such nick/channel")
      else
        matched.each{|target|
          sc = target.socket
          send_server_message(user, "311", target.nick, target.user, target.host, "*", target.real)
          send_server_message(user, "312", target.nick, config[:ServerName], "this server.")
          send_server_message(user, "313", target.nick, "is an IRC operator") if @operators.include?(target)
          chs = []
          target.joined_channels.each{|ch|
            if ch.visible?(user)
              pr = ""
              if ch.mode.op?(target)
                pr = "@"
              else ch.mode.voiced?(target)
                pr = "+"
              end
              chs << pr+ch.name
            end
          }
          send_server_message(user, "319", target.nick, chs.join(" "))
          if target.away?
            away = target.away
            send_server_message(user, "301", target.nick, away)
          end
          send_server_message(user, "318", target.nick, "End of WHOIS list")
        }
      end
    }
  end

  def on_whowas(user, params)
    raise NotEnoughParameter if params.empty?
    params[0].split(",").each{|nick|
      if @users.any?{|us| us.nick == nick}
        send_server_message(user, "312", nick, config[:ServerName], "this server.")
      elsif @old_nicks[nick].empty?
        send_server_message(user, "406", nick, "There was no such nickname")
      else
        @old_nicks[nick].each{|nms|
          send_server_message(user, "314", *nms)
        }
      end
      send_server_message(user, "369", nick, "End of WHOWAS")
    }
  end

  def on_who(user, params)
    raise NotEnoughParameter if params.empty?
    mask = mask_to_regex(params[0])
    chs = @channels.find_all{|name, ch| name =~ mask && ch.visible?(user)}
    unless chs.empty?
      chs.each{|name, ch|
        ch.members.each{|usr|
          sym = usr.away? ? "G" : "H"
          sym += @operators.include?(usr) ? "*" : ""
          sym += ch.mode.op?(usr) ? "@" : (ch.mode.voiced?(usr) ? "+" : "")
          send_server_message(user, "352", usr.name, usr.user, usr.host, config[:ServerName], usr.nick, sym, "0 #{real}")
        }
        send_server_message(user, "315", name, "End of WHO list")
      }
    else
      usrs = @users.find_all{|us| us.nick =~ mask || us.user =~ mask || us.host =~ mask}
      usrs.each{|usr|
        send_server_message(user, "352", "*", usr.user, usr.host, config[:ServerName], usr.nick, "H", "0 #{usr.real}")
        send_server_message(user, "315", usr.nick, "End of WHO list")
      }
    end
  end

  def on_kick(user, params)
    raise NotEnoughParameter if params.size < 2
    chs = params[0].split(",")
    whos = params[1].split(",")
    msg = params[2].to_s
    if chs.size == 1
      if ch = channel(chs[0])
        whos.each{|who|
          if usr = @users.find{|us|us.nick==who}
            handle_reply user, ch.kick(usr, user, msg)
          else
            send_server_message(user, "401", who, "No such nick/channel")
          end
        }
      else
        send_server_message(user, "403", chs[0], "No such channel")
      end
    elsif chs.size == whos.size
      chs.each_with_index{|chn, i|
        if chn = channel(chn)
          if usr = user_from_nick[whos[i]]
            handle_reply user, ch.kick(usr, user, msg)
          else
            send_server_message(user, "401", whos[i], "No such nick/channel")
          end
        else
          send_server_message(user, "403", chn, "No such channel")
        end
      }
    end
  end

  def on_ison(user, params)
    raise NotEnoughParameter if params.empty?
    a = params.find_all{|nick| @users.any?{|us| us.nick == nick}}
    send_server_message(user, "303", a.join(" "))
  end

  def on_userhost(user, params)
    raise NotEnoughParameter if params.empty?
    targs = params[0..4]
    targs.map!{|nick|
      if tg = @users.find{|u| u.nick == nick}
        suf = @operators.include?(tg.socket) ? "*" : ""
        pre = tg.away? ? "-" : "+"
        usr = tg.user
        host = tg.host
        nick + suf + "=" + pre + usr + "@" + host + " "
      else
        ""
      end
    }
    send_server_message(user, "302", targs.join(" "))
  end

  def on_quit(user, params)
    send_client_message(user, nil, ERROR, "Closing", "Link:", "#{user.nick}[#{user.user}@#{user.host}]", %Q!("#{params[0]}")!)
    unregister(user, params[0])
  end

  def handle_reply(user, rpl)
    return unless rpl
    case rpl[0]
    when Array
      rpl.each{|rp|
        handle_reply(user, rp)
      }
    when Command
      send_client_message(user, user, *rpl)
    else
      send_server_message(user, *rpl)
    end
  end

  def send_message(to, from, msg, *args)
    case msg
    when Command
      send_client_message(to, from, msg, *args)
    when Reply
      send_server_message(to, msg, *args)
    end
  end

  def puts_socket(user, *args)
    user.socket.synchronize do
      if user.socket.closed?
        unregister(user, "Connection reset by peer")
      else
        begin
          args.map!{|a| a.to_s.encode config().fetch(:Encoding, "ISO-2022-JP")}
          user.socket.puts(*args)
        rescue Errno::EPIPE => e
          unregister(user, "Connection reset by peer")
        end
      end
    end
  end

  def send_client_message(to, from, cmd, *args)
    msg = cmd.new(from.to_s, cmd.name.split('::').last, args)
    puts_socket(to, msg)
  end

  def send_server_message(to, msg, *args)
    args.unshift to.nick
    puts_socket(to, Message.build(config[:ServerName], msg, args) )
  end

  def channel(chname)
    @channels[chname.downcase]
  end

  def set_channel(cn, val)
    @channels[cn.downcase] = val
  end

  def start(*args)
    @started = Time.now
    super
  end

end
end
