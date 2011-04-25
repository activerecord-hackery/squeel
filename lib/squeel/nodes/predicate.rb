require 'squeel/predicate_methods'
require 'squeel/nodes/predicate_operators'

module Squeel
  module Nodes
    # This node is essentially a container that will result in ARel predicate nodes
    # once visited. It stores the expression (normally an attribute name, function, or
    # operation), the ARel predicate method name, and a value. these are then interpreted
    # when visited by the PredicateVisitor to generate a condition against the appropriate
    # columns.
    class Predicate

      include PredicateMethods
      include PredicateOperators

      # @return The right-hand value being considered in this predicate.
      attr_accessor :value

      # @return The expression on the left side of this predicate.
      attr_reader :expr

      # @return [Symbol] The ARel "predication" method name, such as eq, matches, etc.
      attr_reader :method_name

      # Create a new Predicate node with the given expression, method name, and value
      # @param expr The expression for the left hand side of the predicate.
      # @param [Symbol] method_name The ARel predication method
      # @param value An optional value. If not given, one will need to be supplied
      #   before the node can be visited properly.
      def initialize(expr, method_name = :eq, value = :__undefined__)
        @expr, @method_name, @value = expr, method_name, value
      end

      # Object comparison
      def eql?(other)
        self.class.eql?(other.class) &&
        self.expr.eql?(other.expr) &&
        self.method_name.eql?(other.method_name) &&
        self.value.eql?(other.value)
      end
      alias :== :eql?

      # Implemented for equality testing
      def hash
        [self.class, expr, method_name, value].hash
      end

      # Whether the value has been assigned yet.
      # @return [TrueClass, FalseClass] Has the value been set?
      def value?
        @value != :__undefined__
      end

      # Set the value for this predicate
      # @param val The value to be set
      # @return [Predicate] This predicate, with its new value set
      def %(val)
        @value = val
        self
      end

      # expand_hash_conditions_for_aggregates assumes our hash keys can be
      # converted to symbols, so this has to be implemented, but it doesn't
      # really have to do anything useful.
      # @return [NilClass] Just to avoid bombing out on expand_hash_conditions_for_aggregates
      def to_sym
        nil
      end

    end
  end
end