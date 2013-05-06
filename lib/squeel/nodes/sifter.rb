module Squeel
  module Nodes
    class Sifter < Node
      include PredicateOperators

      attr_reader :name, :args

      def initialize(name, args)
        @name, @args = name, args
      end

      # Implemented for equality testing
      def hash
        [name, args].hash
      end

      # Compare with other objects
      def eql?(other)
        self.class.eql?(other.class) &&
        self.name.eql?(other.name) &&
        self.args.eql?(other.args)
      end
      alias :== :eql?

    end
  end
end
