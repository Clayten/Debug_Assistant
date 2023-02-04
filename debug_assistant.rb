#!/usr/bin/env ruby

load File.join(File.dirname(__FILE__), 'exception.rb')

# Test Classes and Modules to display the source code from in the context of an exception
module Debugger
  # Module Docs
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
      binding.pry
      a + b
    end
  end
  module B
    def self.b
      $pb = binding
      A.a
    end
  end

  def self.check
    $c = $e = nil
    B.b
  rescue StandardError, SystemStackError => e
    puts "Rescue: #{e.inspect}\n"
    $e = e
    e
  end
end
