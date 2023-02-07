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
    def self.a arg
      blk = a_block
      b = Point.new 0,1,2
      s = blk[arg,b]
      puts s
    end

    def self.a_block
      lambda {|x,y|
        x + y
      }
    end
  end
end
