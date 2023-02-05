module Debugger
  class Point
    attr_reader :x, :y, :z
    def initialize x, y, z
      @x, @y, @z = x, y, z
    end
    # undef to_str if instance_method(:to_str) rescue nil
    def to_s ; "(#{x},#{y},#{z})" end
  end

  module A
    def self.a
      a = 'cat'
      b = Point.new 0,1,2
      s = a + b
      puts s
    end
  end
end
