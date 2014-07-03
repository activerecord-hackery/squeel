module Squeel
  module Nodes
    class String
      include PredicateMethods

      def initialize(string)
        @instance = string
      end

      def to_s
        @instance
      end
    end
  end
end
