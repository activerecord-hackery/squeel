require 'squeel/predicate_methods'
require 'squeel/nodes/operators'

module Squeel
  module Nodes
    class Stub

      include PredicateMethods
      include Operators

      attr_reader :symbol

      def initialize(symbol)
        @symbol = symbol
      end

      def eql?(other)
        self.class == other.class &&
        self.symbol == other.symbol
      end

      def hash
        symbol.hash
      end

      def to_sym
        symbol
      end

      def to_s
        symbol.to_s
      end

      def method_missing(method_id, *args)
        super if method_id == :to_ary
        KeyPath.new(self.symbol, method_id)
      end

      def ==(value)
        Predicate.new self.symbol, :eq, value
      end

      # Won't work on Ruby 1.8.x so need to do this conditionally
      define_method('!=') do |value|
        Predicate.new(self.symbol, :not_eq, value)
      end if respond_to?('!=')

      def ^(value)
        Predicate.new self.symbol, :not_eq, value
      end

      def >>(value)
        Predicate.new self.symbol, :in, value
      end

      def <<(value)
        Predicate.new self.symbol, :not_in, value
      end

      def =~(value)
        Predicate.new self.symbol, :matches, value
      end

      # Won't work on Ruby 1.8.x so need to do this conditionally
      define_method('!~') do |value|
        Predicate.new(self.symbol, :does_not_match, value)
      end if respond_to?('!~')

      def >(value)
        Predicate.new self.symbol, :gt, value
      end

      def >=(value)
        Predicate.new self.symbol, :gteq, value
      end

      def <(value)
        Predicate.new self.symbol, :lt, value
      end

      def <=(value)
        Predicate.new self.symbol, :lteq, value
      end

      def asc
        Order.new self.symbol, 1
      end

      def desc
        Order.new self.symbol, -1
      end

      def func(*args)
        Function.new(self.symbol, args)
      end

      alias :[] :func

      def inner
        Join.new(self.symbol, Arel::InnerJoin)
      end

      def outer
        Join.new(self.symbol, Arel::OuterJoin)
      end

      def of_class(klass)
        Join.new(self.symbol, Arel::InnerJoin, klass)
      end

    end
  end
end