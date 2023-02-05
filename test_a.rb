module Debugger
  class Point
    attr_reader :x, :y, :z
    def initialize x, y, z
      @x, @y, @z = x, y, z
    end
  end

  module A
    def self.a
      a = 'cat'
      b = Point.new 0,1,2
      a + b
    end
  end
end
