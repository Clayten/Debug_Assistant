module Debugger
  module B
    def self.b
      b2
    end

    def self.b2
      A.a 'cat'
    end
  end
end
