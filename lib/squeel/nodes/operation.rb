require 'squeel/nodes/function'

module Squeel
  module Nodes
    # An Operation is basically a function with its operands limited, and rearranged,
    # so Squeel implements it as such.
    class Operation < Function

      # Create a new Operation with the given operator and left and right operands
      # @param left The left operand
      # @param [String, Symbol] operator The operator
      # @param right The right operand
      def initialize(left, operator, right)
        super(operator, [left, right])
      end

      # An operation should probably call its "function" name an "operator", shouldn't it?
      alias :operator :function_name

      # @return The left operand
      def left
        args[0]
      end

      # @return The right operand
      def right
        args[1]
      end

    end
  end
end
