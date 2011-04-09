module Squeel
  module Nodes
    module Operators

      def +(value)
        Operation.new(self, :+, value)
      end

      def -(value)
        Operation.new(self, :-, value)
      end

      def *(value)
        Operation.new(self, :*, value)
      end

      def /(value)
        Operation.new(self, :/, value)
      end

      def op(operator, value)
        Operation.new(self, operator, value)
      end

    end
  end
end