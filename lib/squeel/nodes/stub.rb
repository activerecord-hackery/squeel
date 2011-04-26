require 'squeel/predicate_methods'
require 'squeel/nodes/operators'

module Squeel
  module Nodes
    # Stub nodes are basically a container for a Symbol that can have handy predicate
    # methods and operators defined on it since doing so on Symbol will incur the
    # nerdrage of many.
    class Stub

      include PredicateMethods
      include Operators

      alias :== :eq
      alias :'^' :not_eq
      alias :'!=' :not_eq if respond_to?(:'!=')
      alias :>> :in
      alias :<< :not_in
      alias :=~ :matches
      alias :'!~' :does_not_match if respond_to?(:'!~')
      alias :> :gt
      alias :>= :gteq
      alias :< :lt
      alias :<= :lteq

      undef_method :id if method_defined?(:id)

      # @return [Symbol] The symbol contained by this stub
      attr_reader :symbol

      # Create a new Stub.
      # @param [Symbol] symbol The symbol that this Stub contains
      def initialize(symbol)
        @symbol = symbol
      end

      # Object comparison
      def eql?(other)
        self.class == other.class &&
        self.symbol == other.symbol
      end

      # To support object equality tests
      def hash
        symbol.hash
      end

      # @return [Symbol] The symbol this Stub contains.
      def to_sym
        symbol
      end

      # @return [String] The Stub's String equivalent.
      def to_s
        symbol.to_s
      end

      # Create a KeyPath when any undefined method is called on a Stub.
      # @overload node_name
      #   Creates a new KeyPath with this Stub as the base and the method_name as the endpoint
      #   @return [KeyPath] The new keypath
      # @overload node_name(klass)
      #   Creates a new KeyPath with this Stub as the base and a polymorphic belongs_to join as the endpoint
      #   @param [Class] klass The polymorphic class for the join
      #   @return [KeyPath] The new keypath
      def method_missing(method_id, *args)
        super if method_id == :to_ary
        if (args.size == 1) && (Class === args[0])
          KeyPath.new(self, Join.new(method_id, Arel::InnerJoin, args[0]))
        else
          KeyPath.new(self, method_id)
        end
      end

      # Return a KeyPath containing only this Stub, but flagged as absolute.
      # This helps Stubs behave more like a KeyPath, as anyone using the Squeel
      # DSL is likely to think of them as such.
      # @return [KeyPath] An absolute KeyPath, containing only this Stub
      def ~
        KeyPath.new [], self, true
      end

      # Create an ascending Order node with this Stub's symbol as its expression
      # @return [Order] The new Order node
      def asc
        Order.new self.symbol, 1
      end

      # Create a descending Order node with this Stub's symbol as its expression
      # @return [Order] The new Order node
      def desc
        Order.new self.symbol, -1
      end

      # Create a Function node for a function named the same as this Stub and with the given arguments
      # @return [Function] The new Function node
      def func(*args)
        Function.new(self.symbol, args)
      end

      # Create an inner Join node for the association named by this Stub
      # @return [Join] The new inner Join node
      def inner
        Join.new(self.symbol, Arel::InnerJoin)
      end

      # Create an outer Join node for the association named by this Stub
      # @return [Join] The new outer Join node
      def outer
        Join.new(self.symbol, Arel::OuterJoin)
      end

      # Create a polymorphic Join node for the association named by this Stub,
      # @param [Class] klass The polymorphic belongs_to class for this Join
      # @return [Join] The new polymorphic Join node
      def of_class(klass)
        Join.new(self.symbol, Arel::InnerJoin, klass)
      end

    end
  end
end