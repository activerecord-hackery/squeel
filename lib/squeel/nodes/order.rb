module Squeel
  module Nodes
    class Order
      attr_reader :expr, :direction

      def initialize(expr, direction = 1)
        raise ArgumentError, "Direction #{direction} is not valid. Must be -1 or 1." unless [-1,1].include? direction
        @expr, @direction = expr, direction
      end

      def asc
        @direction = 1
        self
      end

      def desc
        @direction = -1
        self
      end

      def ascending?
        @direction == 1
      end

      def descending?
        @direction == -1
      end

      def reverse!
        @direction = - @direction
        self
      end
    end
  end
end