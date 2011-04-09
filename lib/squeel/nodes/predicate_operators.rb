module Squeel
  module Nodes
    module PredicateOperators
      def |(other)
        Or.new(self, other)
      end

      def &(other)
        And.new([self, other])
      end

      def -@
        Not.new(self)
      end
    end
  end
end