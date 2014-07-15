module Squeel
  module Nodes
    class SubqueryJoin < Node
      attr_accessor :subquery, :type, :constraints

      def initialize(subquery, constraints, type = Squeel::InnerJoin)
        raise ArgumentError,
          "subquery(#{subquery}) isn't an Squeel::Nodes::As" unless subquery.is_a?(As)

        raise ArgumentError,
          "constraints(#{constraints}) isn't a Squeel::Nodes::Node" unless constraints.is_a?(Node)

        self.subquery = subquery
        self.constraints = constraints
        self.type = type
      end

      # Implemented for equality testing
      def hash
        [subquery, type, constraints].hash
      end

      def inner
        self.type = Squeel::InnerJoin
        self
      end

      def outer
        self.type = Squeel::OuterJoin
        self
      end

      # Compare with other objects
      def eql?(other)
        self.class.eql?(other.class) &&
        self.subquery.eql?(other.subquery) &&
        self.type.eql?(other.type) &&
        self.constraints.eql?(other.constraints)
      end
      alias :== :eql?

    end
  end
end
