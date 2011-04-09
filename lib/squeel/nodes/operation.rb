require 'squeel/nodes/function'

module Squeel
  module Nodes
    class Operation < Function

      def initialize(left, operator, right)
        super(operator, [left, right])
      end

      alias :operator :name

      def left
        args[0]
      end

      def right
        args[1]
      end

    end
  end
end