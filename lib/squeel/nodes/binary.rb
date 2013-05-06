module Squeel
  module Nodes
    # A node that represents an operation with two operands.
    class Binary < Node

      include PredicateOperators

      # The left operand
      attr_reader :left

      # The right operand
      attr_reader :right

      # @param left The left operand
      # @param right The right operand
      def initialize(left, right)
        @left, @right = left, right
      end

      def hash
        [@left, @right].hash
      end

      # Comparison with other nodes
      def eql?(other)
        self.class.eql?(other.class) &&
        self.left.eql?(other.left) &&
        self.right.eql?(other.right)
      end

    end
  end
end
