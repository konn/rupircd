=begin
= rupircd -- Ruby Pseudo IRC Deamon

  ver 0.5b1 2007-05-18T22:30:56+09:00
  
  Copyright (c) 2007 konn <banzaida_at_jcom_dot_home_dot_ne_dot_jp>
  
  You can redistribute it and/or modify it under the same term as Ruby.
=end

require "nkf"

class String
  Flag = {
    NKF::UTF8 => "-W", NKF::SJIS => "-S",
    NKF::JIS => "-J", NKF::EUC => "-E"
  }
  
  def tojis
    flag = Flag[NKF.guess(self)]
    NKF.nkf("#{flag} -j", self)
  end
  
  def toutf8
    flag = Flag[NKF.guess(self)]
    NKF.nkf("#{flag} -w8", self)[3..-1]
  end
  
  def toutf8!
    self[0..-1] = toutf8
  end
  
  def tojis!
    self[0..-1] = tojis
  end
end