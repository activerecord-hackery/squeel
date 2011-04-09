module Squeel
  module Nodes
    class Nary
      include PredicateOperators

      attr_reader :children

      def initialize(children)
        raise ArgumentError, '#{self.class} requires an array' unless Array === children
        # We don't dup here, as incoming arrays should be created by the
        # Operators#& method on other nodes. If you're creating And nodes
        # manually, by sure that they're new arays.
        @children = children
      end

      def &(other)
        @children << other
        self
      end

      def -(other)
        @children << Not.new(other)
        self
      end

      def eql?(other)
        self.class     == other.class &&
        self.children  == other.children
      end

      alias :== :eql?

    end
  end
end