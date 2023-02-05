module Debugger
  module C
    class << self
      undef c_orig if instance_method(:c_orig) rescue nil
      def c
        B.b
      end
    end
  end
end
