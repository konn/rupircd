=begin
= rupircd -- Ruby Pseudo IRC Deamon

  ver 0.5b2 2008-08-27T12:17:46+09:00
  
  Copyright (c) 2008 Hiromi Ishii
  
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