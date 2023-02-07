#!/usr/bin/env ruby

%w(proxy exception ai test_a test_b test_c).each {|fn| load File.join(File.dirname(__FILE__), "#{fn}.rb") }

# Test Classes and Modules to display the source code from in the context of an exception
module Debugger
  # Debugger module docs

  module C
    class << self
      alias c_orig c
      def c
        c_orig
      end
    end
  end

  def self.check
    C.c
  rescue StandardError, SystemStackError => e
    puts "Rescue: #{e.inspect}\n"
    e
  end
end
