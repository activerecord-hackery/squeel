require 'squeel/nodes/order'

module Squeel
  module Nodes
    module Ordering

      # Create an ascending Order node with this Node as its expression
      # @return [Order] The new Order node
      def asc
        Order.new self, 1
      end

      # Create a descending Order node with this Node as its expression
      # @return [Order] The new Order node
      def desc
        Order.new self, -1
      end

    end
  end
end
