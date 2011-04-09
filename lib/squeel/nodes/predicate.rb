require 'squeel/predicate_methods'
require 'squeel/nodes/predicate_operators'

module Squeel
  module Nodes
    class Predicate

      include PredicateMethods
      include PredicateOperators

      attr_accessor :value
      attr_reader :expr, :method_name

      def initialize(expr, method_name = :eq, value = :__undefined__)
        @expr, @method_name, @value = expr, method_name, value
      end

      def eql?(other)
        self.class.eql?(other.class) &&
        self.expr.eql?(other.expr) &&
        self.method_name.eql?(other.method_name) &&
        self.value.eql?(other.value)
      end

      alias :== :eql?

      def hash
        [self.class, expr, method_name, value].hash
      end

      def value?
        @value != :__undefined__
      end

      def %(val)
        @value = val
        self
      end

      # expand_hash_conditions_for_aggregates assumes our hash keys can be
      # converted to symbols, so this has to be implemented, but it doesn't
      # really have to do anything useful.
      def to_sym
        nil
      end

    end
  end
end