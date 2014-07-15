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

      def on(*args)
        raise "only can convert ActiveRecord::Relation to a join node" unless left.is_a?(ActiveRecord::Relation)
        proc =
          if block_given?
            DSL.eval(&Proc.new)
          else
            args
          end

        SubqueryJoin.new(self, proc)
      end
    end
  end
end
