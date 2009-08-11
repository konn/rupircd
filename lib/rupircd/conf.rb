=begin
= rupircd -- Ruby Pseudo IRC Deamon

  ver 0.6 2009-08-11T23:45:52+09:00
  
  Copyright (c) 2009 Hiromi Ishii
  
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