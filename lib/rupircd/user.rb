=begin
= rupircd -- Ruby Pseudo IRC Deamon

  ver 0.6 2009-08-11T23:45:52+09:00
  
  Copyright (c) 2009 Hiromi Ishii
  
  You can redistribute it and/or modify it under the same term as Ruby.
=end

require 'rupircd/channel'

module IRCd

class User
  attr_reader :user, :host, :identifier, :socket
  attr_accessor :nick, :away, :invisible, :wallop, :restriction, :operator, :local_operator, :s, :joined_channels, :real
  @@identifier = 0

  def to_s
    @nick + "!" + @user + "@" + @host
  end

  def initialize(nick, user, host, real, socket, mode=0)
    @nick = nick
    @user = user
    @host = host
    @real = real
    @identifier = (@@identifier += 1)
    @away = ""
    @invisible = false
    @wallop = false
    @restriction = false
    @operator = false
    @local_operator = false
    @s = false
    @socket = socket
    @joined_channels = []
  end

  def away?
    !@away.empty?
  end

  def to_a
    [@nick, @user, @host, "*", @real]
  end

  def set_flags(*flags)
    rls = []
    flags.each{|flg|
      fl = flg[0,1]
      toggle = flg[0] == ?+
      flg[1..-1].split("").each{|md|
        case md
        when "i"
          @invisible = toggle
          fl << "i"
        when "w"
          @wallop = toggle
          fl << "w"
        when"r"
          if toggle
            @restriction = true
            fl << "r"
          end
        when "o"
          unless toggle
            @operator = false
            fl << "o"
          end
        when "O"
          unless toggle
            @local_operator = false
            fl << "O"
          end
        when "s"
          @s = toggle
          fl << "s"
        end
      }
      rls << fl
    }
    rls
  end

  def get_mode_flags
    mode = ""
    mode << "i" if @invisible
    mode << "w" if @wallop
    mode << "r" if @restriction
    mode << "o" if @operator
    mode << "O" if @local_operator
    mode << "s" if @s
    mode
  end

  def ==(other)
    @identifier == other.identifier
  end

end
end