#!/usr/bin/env ruby

# Capture the variables from the site of an exception and display relevant info
#
# https://stackoverflow.com/questions/7647103/can-i-access-the-binding-at-the-moment-of-an-exception-in-ruby
# https://stackoverflow.com/questions/106920/how-can-i-get-source-and-variable-values-in-ruby-tracebacks
#

module ExceptionBinding
  attr_reader :call_binding

  def local_variables
    $lv = eval "local_variables.map {|v| [v, eval(v.to_s)] }", call_binding if call_binding
  end

  def method
    p :method
    p backtrace
    error_line = backtrace.first
    error_line_num = error_line.scan(/\d+/).first.to_i
    last_line = error_line

    backtrace.each {|btl|
      btln = btl.scan(/\d+/).first.to_i
      p [:btl, btl, :btln, btln]
      break if btln != error_line_num
      last_line = btl
    }
    last_line.scan(/`([^'])'/).first
  end

  def method_code
    p [:slf, self]
    Pry::CodeObject.lookup()
  end

  def context
  end

  def initialize *a
    # p [:E_init!, *a]
    super *a
    # Find the calling location
    $c = caller
    expected_file, expected_line = caller(1).first.split(':')[0,2]
    expected_line = expected_line.to_i
    # p [:E_init, :expected, "#{expected_file}:#{expected_line}"]
    return_count = 5  # If we see more than 5 returns, stop tracing
    $lw = line_window = (expected_line - 5 .. expected_line)

    # Start tracing until we see our caller.
    set_trace_func(proc do |event, file, line, id, binding, kls|
      # p [:E_init, :stf, :e, event, "#{file}:#{line}", kls, id, :b, binding] if file == expected_file

      if file == expected_file && line_window.include?(line)
        p [:E_init, :stf, :match, :b, binding] if binding
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
class StandardError < Exception ; include ExceptionBinding end
class SystemStackError < Exception ; include ExceptionBinding end

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
  module B
    def self.b
      A.a
    end
  end

  def self.check
    $c = $e = $b = $lv = nil
    B.b
  rescue StandardError, SystemStackError => e
    puts "Rescue: #{e.inspect}\n"
    $e = e
    $b = e.call_binding
    e
  end
end
