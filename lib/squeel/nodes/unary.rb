require 'squeel/nodes/predicate_operators'

module Squeel
  module Nodes
    # A node that contains a single expression.
    class Unary

      include PredicateOperators

      # @return The expression contained in the node
      attr_reader :expr

      # Create a new Unary node.
      # @param expr The expression to contain inside the node.
      def initialize(expr)
        @expr = expr
      end

      # Object comparison
      def eql?(other)
        self.class == other.class &&
        self.expr  == other.expr
      end
      alias :== :eql?

    end
  end
end