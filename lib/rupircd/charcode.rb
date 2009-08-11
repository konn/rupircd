=begin
= rupircd -- Ruby Pseudo IRC Deamon

  ver 0.6 2009-08-11T23:45:52+09:00
  
  Copyright (c) 2009 Hiromi Ishii
  
  You can redistribute it and/or modify it under the same term as Ruby.
=end

require "nkf"

class String
  Flag = {
    NKF::UTF8 => "-W", NKF::SJIS => "-S",
    NKF::JIS => "-J", NKF::EUC => "-E",
    "Shift_JIS" => "-S", "UTF-8" => "-W",
    "ISO-2022-JP" => "-J", "EUC-JP" => "-E"
  }
  
  def tojis
    if RUBY_VERSION < "1.9"
      flag = Flag[NKF.guess(self)]
      NKF.nkf("#{flag} -j", self)
    else
      self.encode("ISO-2022-JP")
    end
  end

  if RUBY_VERSION < "1.9"
    def encode(code)
      flag = Flag[NKF.guess self]
      NKF.nkf("#{flag} #{Flag[code].downcase}", self)
    end

    
    def encode!(code)
      replace encode(code)
    end
  end
  
  def toutf8
    if RUBY_VERSION < "1.9"
      flag = Flag[NKF.guess(self)]
      NKF.nkf("#{flag} -w8", self)[3..-1]
    else
      self.encode("UTF-8")
    end
  end
  
  def toutf8!
    replace(toutf8)
  end

  def tojis!
    replace(tojis)
  end
end