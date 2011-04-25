module Squeel
  module Nodes
    # Module containing Operation factory methods for inclusion in Squeel nodes
    module Operators

      # Factory for a new addition operation with this node as its left operand.
      # @param value The right operand
      # @return [Operation] The new addition operation
      def +(value)
        Operation.new(self, :+, value)
      end

      # Factory for a new subtraction operation with this node as its left operand.
      # @param value The right operand
      # @return [Operation] The new subtraction operation
      def -(value)
        Operation.new(self, :-, value)
      end

      # Factory for a new multiplication operation with this node as its left operand.
      # @param value The right operand
      # @return [Operation] The new multiplication operation
      def *(value)
        Operation.new(self, :*, value)
      end

      # Factory for a new division operation with this node as its left operand.
      # @param value The right operand
      # @return [Operation] The new division operation
      def /(value)
        Operation.new(self, :/, value)
      end

      # Factory for a new custom operation with this node as its left operand.
      # @param value The right operand
      # @return [Operation] The new operation
      def op(operator, value)
        Operation.new(self, operator, value)
      end

    end
  end
end