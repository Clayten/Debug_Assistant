#!/usr/bin/env ruby

class Foo < Exception
  attr_reader :call_binding

  def initialize
    # p [:E_init]
    # super
    # Find the calling location
    $c = caller
    expected_file, expected_line = caller(1).first.split(':')[0,2]
    expected_line = expected_line.to_i
    # p [:E_init, :expected, "#{expected_file}:#{expected_line}"]
    return_count = 5  # If we see more than 5 returns, stop tracing

    # Start tracing until we see our caller.
    set_trace_func(proc do |event, file, line, id, binding, kls|
      # p [:E_init, :stf, :e, event, "#{file}:#{line}", kls, id, :b, binding] if file == expected_file
      if file == expected_file && (line == expected_line || line == expected_line - 1)
        # p [:E_init, :stf, :match, :b, binding]
        # Found it: Save the binding and stop tracing
        @call_binding = binding
        set_trace_func(nil) if binding
      end

      if event == :return
        # p [:E_init, :stf, :give_up]
        # Seen too many returns, give up. :-(
        set_trace_func(nil) if (return_count -= 1) <= 0
      end
    end)
    # p [:E_init, :stf, :done]
  end
end

module Debugger
  class Point
    def initialize x, y, z
      @x, @y, @z = x, y, z
    end
  end
	module A
		def self.a
			a = 'cat'
      b = Point.new 0,42,-Math::PI
      raise Foo
			a + b
    end
  end
  module B
    def self.b
      A.a
    end
  end

  def self.check
    $c = $e = $b = $lv = nil
    B.b
  rescue Foo => e
    puts "Rescue: #{e.inspect}\n"
    $e = e
    $b = e.call_binding
    $lv = eval "local_variables.map {|v| [v, eval(v.to_s)] }", e.call_binding
    p [:rescue, :local_variables, $lv.map {|n,v| [n,v.class,v]}]
    e
  end
end
