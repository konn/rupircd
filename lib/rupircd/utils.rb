=begin
= rupircd -- Ruby Pseudo IRC Deamon

  ver 0.5b1 2007-05-18T22:30:56+09:00
  
  Copyright (c) 2007 konn <banzaida_at_jcom_dot_home_dot_ne_dot_jp>
  
  You can redistribute it and/or modify it under the same term as Ruby.
=end

module IRCd

module Utils

  def channame?(str)
    str =~ /^[#+!\+]/
  end

  def correct_nick?(nick)
    nick =~ /^[a-zA-Z\x5B-\x60\x7B-\x7D][-\w\x5B-\x60\x7B-\x7D]{0,14}$/
  end

  def mask_to_regex(mask)
    mask = Regexp.escape(mask)
    mask.gsub!('\*', '.*')
    mask.gsub!('\?', '.')
    return Regexp.new('^' + mask + '$')
  end

end

end