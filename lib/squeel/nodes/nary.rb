module Squeel
  module Nodes
    # A node containing multiple children. Just the And node for now.
    class Nary < Node
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

      # Returns a new Nary node, with an additional child.
      # @param other A new child node
      # @return [Nary] This node, with its updated children.
      def &(other)
        self.class.new(@children + [other])
      end

      # Returns a new Nary node, with an additional (negated) child.
      # @param other A new child node
      # @return [Nary] This node, with its new, negated child
      def -(other)
        self.class.new(@children + [Not.new(other)])
      end

      # Implemented for equality testing
      def hash
        @children.hash
      end

      # Object comparison
      def eql?(other)
        self.class.eql?(other.class) &&
        self.children.eql?(other.children)
      end

    end
  end
end
