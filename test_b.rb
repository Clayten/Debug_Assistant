module Debugger
  module B
    def self.b
      b2
    end

    def self.b2
      $pb = binding
      A.a
    end
  end
end