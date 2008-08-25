=begin
= rupircd -- Ruby Pseudo IRC Deamon

  ver 0.5b1 2007-05-18T22:30:56+09:00
  
  Copyright (c) 2007 konn <banzaida_at_jcom_dot_home_dot_ne_dot_jp>
  
  You can redistribute it and/or modify it under the same term as Ruby.
=end

module IRCd
  class FileConf
    attr_reader :conf
    attr_accessor :path

    def initialize(path)
      @path = path
      @conf = {}
    end

    def load
      @conf = eval(open(@path){|f| f.read })
    end

  end
end