require 'squeel/nodes/predicate_operators'

module Squeel
  module Nodes
    class Unary
      include PredicateOperators

      attr_reader :expr

      def initialize(expr)
        @expr = expr
      end

      def eql?(other)
        self.class == other.class &&
        self.expr  == other.expr
      end

      alias :== :eql?
    end
  end
end