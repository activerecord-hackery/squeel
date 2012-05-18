require 'squeel/nodes/binary'

module Squeel
  module Nodes
    # A node representing an SQL alias, which will result in same when visited.
    class As < Binary
      alias :expr :left
      alias :alias :right

      # @param left The node to be aliased
      # @param right The alias name
      def initialize(left, right)
        @left, @right = left, right
      end
    end
  end
end
