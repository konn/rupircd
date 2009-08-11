=begin
= rupircd -- Ruby Pseudo IRC Deamon

  ver 0.6 2009-08-11T23:45:52+09:00
  
  Copyright (c) 2009 Hiromi Ishii
  
  You can redistribute it and/or modify it under the same term as Ruby.
=end

require 'rupircd/utils'
require 'rupircd/message'

module IRCd

class ChannelMode
  include Utils
  attr_accessor :bans, :topic_op_only, :ops, :invite, :voices, :anony, :moderate, :n,
                :quiet, :private, :secret, :reops, :key, :user_max, :excepts,
                :dont_need_invite, :creators
  
  def initialize(server, chname)
    @chname = chname
    @server = server
    @bans = []
    @topic_op_only = false
    @creators = []
    @ops = []
    @invite = false
    @voices = []
    @anony = false
    @moderate = false
    @n = false
    @quiet = false
    @private = false
    @secret = false
    @reops = []
    @key = ""
    @user_max = -1
    @excepts = []
    @invite_onlys = []
  end

  def set_flags(who, flags, param)
    args = param.dup
    toggle = flags[0] == ?+
    rpl = [flags[0,1]]
    flags = flags[1..3]
    flags.each_byte{|b|
      rpl.push b.chr
      case b
      when ?n
        @n = toggle
      when ?i
        @invite = toggle
      when ?a
        @anony = toggle
      when ?m
        @moderate = toggle
      when ?p
        @secret = false if toggle
        @private = toggle
      when ?s
        @private = false if toggle
        @secret = toggle
      when ?k
        key = param.shift
        if toggle
          @key = key
        elsif key == @key
          @key = ""
        end
      when ?l
        @user_max = param.shift.to_i
      when ?r
        if toggle
          @reops << mask_to_regex(param.shift)
        else
          @reops.delete(mask_to_regex(param.shift))
        end
      when ?t
        @topic_op_only = toggle
      when ?o
        user = @server.user_from_nick(param.shift)
        if toggle
          @ops << user
          @ops.compact!
          @ops.uniq!
        else
          @ops.delete(user)
        end
      when ?v
        user = @server.user_from_nick(param.shift)
        if toggle
          @voices << user
          @voices.uniq!
          @voices.compact!
        else
          @voices.delete(user)
        end
      when ?b, ?e, ?I
        masks = param.shift
        mask_list = []
        list_msg = ""
        endof_msg = ""
        what = ""
        case b
        when ?b
          mask_list = @bans
          list_msg = "367"
          endof_msg = "368"
          what = "ban"
        when ?e
          mask_list = @excepts
          list_msg = "348"
          endof_msg = "349"
          what = "exception"
        when ?I
          mask_list = @invite_onlys
          list_msg = "346"
          endof_msg = "347"
          what = "invite"
        end
        if masks
          if toggle
            mask_list << mask_to_regex(masks)
          else
            mask_list.delete(mask_to_regex(masks))
          end
        else
          rpl.pop
          mask_list.each{|msk|
            @server.send_server_message(who, list_msg, @chname, msk)
          }
          @server.send_server_message(who, endof_msg, @chname, "End of channel #{what} list")
        end
      else
        @server.send_server_message(who, "472", rpl.pop, "is unknown mode char to me for #@chname")
      end
    }
    [rpl.join(""), args].flatten if rpl.size > 1
  end

  def proc_mask(toggle, rpl, param, mask_list, reply_msg, endof_list, name)
    masks = param.shift
    if masks
      if toggle
        mask_list << mask_to_regex(masks)
      else
        mask_list.delete(mask_to_regex(masks))
      end
    else
      rpl.pop
      mask_list.each{|msk|
        @server.send_server_message(who, reply_msg, @chname, msk)
      }
      @server.send_server_message(who, endof_list, @chname, "End of channel #{name} list")
    end
  end
  private :proc_mask

  def get_flags
    params = []
    flg = "+"
    flg << "n" if @n
    flg << "i" if @invite
    flg << "a" if @anony
    flg << "m" if @moderate
    flg << "q" if @quiet
    flg << "p" if @private
    flg << "s" if @secret
    flg << "k" unless @key.empty?
    flg << "t" if @topic_op_only
    if @user_max > -1
      flg << "l"
      params << @user_max
    end
    params.unshift flg
  end

  def add_op(hoge)
    @ops.push hoge
  end

  def unregister(who)
    @ops.delete(who)
    @voices.delete(who)
  end

  def op?(who)
    @ops.include?(who)
  end

  def voiced?(who)
    @voices.include?(who)
  end

  def can_change_topic?(who)
    !@topic_op_only || op?(who)
  end

  def can_talk?(who)
    !@moderate || op?(who) || @voices.include?(who)
  end

  def can_invite?(who)
    !@invite || op?(who)
  end

  def banned?(who)
    @bans.any?{|mask|
      who.to_s =~ mask
    }
  end

end

class Channel
  attr_reader :name, :members, :mode

  def initialize(server, who, chname)
    @server = server
    @mode = ChannelMode.new(server, chname)
    @name = chname
    @topic = ""
    @members = []
    @invited = []
  end

  def join(who, key="")
    if @mode.banned?(who)
      ["474", @name, "Cannot join channel (+b)"]
    elsif @mode.invite && !@invited.include?(who)
      ["473", @name, "Cannot join channel (+i)"]
    elsif !@mode.key.empty? && @mode.key != key
      ["475", @name, "Cannot join channel (+k)"]
    elsif @mode.user_max >= @members.size
      ["471", @name, "Cannot join channel (+l)"]
    elsif !joined?(who)
      who.joined_channels.push self
      @members.unshift who
      
      @mode.add_op who if @members.size == 1
      sends = []
      sends << get_topic(who)
      sends += names(who)
      @server.send_client_message(who, who, Command::JOIN, @name)
      @server.handle_reply(who, sends)
      send_to_other_members(who, Command::JOIN, @name)
      return nil
    end
  end

  def kick(who, by, msg="no reason")
    if !@members.include?(by)
      ["442", @name, "You're not on that channel"]
    elsif !@members.include?(who)
      ["441", who.nick, @name, "They aren't on that channel"]
    elsif @mode.op?(by)
      send_to_members(by, Command::KICK, @name, who.nick, msg)
      unregister(who)
      nil
    else
      ["482", @name, "You're not channel operator"]
    end
  end

  def send_to_members(user, command, *args)
    @members.each{|mem|
      @server.send_client_message(mem, user, command, *args)
    }
  end

  def send_to_other_members(user, command, *args)
    (@members-[user]).each{|mem|
      @server.send_client_message(mem, user, command, *args)
    }
  end

  def joined?(who)
    @members.include?(who)
  end

  def invite(from, who)
    if !joined?(from)
      return ["442", @name, "You're not on that channel"]
    elsif joined?(who)
      return ["443", who.nick, "is already on channel"]
    elsif !@mode.can_invite?(from)
      return ["482", @name, "You're not channel operator"]
    else 
      @invited.push who
      @server.send_client_message(who, from, Command::INVITE, who.nick, @name)
      return ["341", who.nick, @name]
    end
  end

  def unregister(usr)
    @members.delete(usr)
    @mode.unregister(usr)
    usr.joined_channels.delete(self)
  end

  def handle_mode(who, params)
    if params.empty?
      ["324", @name, *@mode.get_flags]
    else
      flags, *targets = params
      flags = "+" + flags if flags[0,1] != "+" && flags[0,1] != "-"
      if @mode.op?(who)
        rpl = @mode.set_flags(who, flags, targets)
        send_to_members(who, Command::MODE, @name, *rpl) if rpl
        nil
      elsif !joined?(who)
        return ["482", @name, "You're not channel operator"]
      else
        return ["442", @name, "You're not on that channel"]
      end
    end
  end

  def part(who, message="")
    if joined?(who)
      send_to_members(who, Command::PART, @name, message)
      unregister(who)
      return nil
    else
      return ["442", @name, "You're not on that channel"]
    end
  end

  def set_topic(who, str)
    if @mode.can_change_topic?(who)
      @topic = str
      send_to_members(who, Command::TOPIC, @name, @topic)
      return nil
    elsif !@members.include?(who)
      return ["442", @name, "You're not on that channel"]
    else
      return ["482", @name, "You're not channel operator"]
    end
  end

  def get_topic(user, text=false)
    return nil if @mode.secret && !joined?(user)
    return @topic if text
    if @topic.empty?
      ["331", @name, "No topic is set"]
    else
      ["332", @name, @topic]
    end
  end

  def privmsg(who, msg)
    if @mode.n && !@members.include?(who)
      return ["404", @name, "Cannot send to channel"]
    elsif @mode.can_talk?(who)
      send_to_other_members(who, Command::PRIVMSG, @name, msg)
      nil
    else
      return ["404", @name, "Cannot send to channel"]
    end
  end

  def notice(who, msg)
    if @mode.can_talk?(who)
      send_to_other_members(who, Command::NOTICE, @name, msg)
    end
    return nil
  end

  def visible?(user)
    !@mode.secret || joined?(user)
  end

  def names(user)
    return nil if @mode.secret && !joined?(user)
    mems = @members.dup
    unless @members.include?(user)
      mems = mems.find_all{|usr|
        !usr.invisible
      }
    end
    memlist = mems.map{|us|
      if @mode.op?(us)
        pr = "@"
      else
        pr = ""
      end
      pr+us.nick
    }.join(" ")
    sends = []
    unless memlist.empty?
      prefix = if @mode.secret
        "@"
      elsif @mode.private
        "*"
      else
        "="
      end
      sends << ["353", prefix, @name, memlist]
    end
    sends << ["366", @name, "End of NAMES list"]
    sends
  end

end

class NoModeChannel < Channel
  def handle_mode(user, *ar)
    ["477", @name, "Channel doesn't support modes"]
  end
end

class SafeChannel < Channel
end # 仕様 がよく分から ない ので実装出来なくても しよう がない

end