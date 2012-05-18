module Squeel
  module Nodes
    # A node containing multiple children. Just the And node for now.
    class Nary
      include PredicateOperators

      # @return [Array] This node's children
      attr_reader :children

      # Creates a new Nary node with the given array of children
      # @param [Array] children The node's children
      def initialize(children)
        raise ArgumentError, '#{self.class} requires an array' unless Array === children
        # We don't dup here, as incoming arrays should be created by the
        # PredicateOperators#& method on other nodes. If you're creating And nodes
        # manually, by sure that they're new arays.
        @children = children
      end

      # Add a new child to the node's children
      # @param other A new child node
      # @return [Nary] This node, with its updated children.
      def &(other)
        @children << other
        self
      end

      # Append a new Not node to this node's children
      # @param other A new child node
      # @return [Nary] This node, with its new, negated child
      def -(other)
        @children << Not.new(other)
        self
      end

      # Implemented for equality testing
      def hash
        [self.class].concat(self.children).hash
      end

      # Object comparison
      def eql?(other)
        self.class.eql?(other.class) &&
        self.children.eql?(other.children)
      end

    end
  end
end
