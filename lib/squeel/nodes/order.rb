module Squeel
  module Nodes
    # A node that represents SQL orderings, such as "people.id DESC"
    class Order < Node
      # @return The expression being ordered on. Might be an attribute, function, or operation
      attr_reader :expr

      # @return [Integer] 1 or -1, depending on ascending or descending direction, respectively
      attr_reader :direction

      # Create a new Order node with the given expression and direction
      # @param expr The expression to order on
      # @param [Integer] direction 1 or -1, depending on the desired sort direction
      def initialize(expr, direction = 1)
        raise ArgumentError, "Direction #{direction} is not valid. Must be -1 or 1." unless [-1,1].include? direction
        @expr, @direction = expr, direction
      end

      # Set this node's direction to ascending
      # @return [Order] This order node with an ascending direction
      def asc
        @direction = 1
        self
      end

      # Set this node's direction to descending
      # @return [Order] This order node with a descending direction
      def desc
        @direction = -1
        self
      end

      # Whether or not this node represents an ascending order
      # @return [Boolean] True if the order is ascending
      def ascending?
        @direction == 1
      end

      # Whether or not this node represents a descending order
      # @return [Boolean] True if the order is descending
      def descending?
        @direction == -1
      end

      # Reverse the node's direction
      # @return [Order] This node with a reversed direction
      def reverse!
        @direction = - @direction
        self
      end

      def hash
        [@expr, @direction].hash
      end

      def eql?(other)
        self.class.eql?(other.class) &&
          self.expr.eql?(other.expr) &&
          self.direction.eql?(other.direction)
      end
    end
  end
end
