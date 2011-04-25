module Squeel
  module Nodes
    # Operators that act as factories for Or, And, and Not nodes for inclusion
    # in classes which can be contained inside these nodes.
    module PredicateOperators

      # Create a new Or node, with this node as its left-hand node.
      # @param other The right-hand node for the Or
      # @return [Or] The new Or node
      def |(other)
        Or.new(self, other)
      end

      # Create a new And node, with this node as its left-hand node.
      # @param other The right-hand node for the And
      # @return [And] The new And node
      def &(other)
        And.new([self, other])
      end

      # Create a new Not node, with this node as its expression
      # @return [Not] The new Not node
      def -@
        Not.new(self)
      end

    end
  end
end