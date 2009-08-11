=begin
= rupircd -- Ruby Pseudo IRC Deamon

  ver 0.6 2009-08-11T23:45:52+09:00
  
  Copyright (c) 2009 Hiromi Ishii
  
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