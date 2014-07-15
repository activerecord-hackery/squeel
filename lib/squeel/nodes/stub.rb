module Squeel
  module Nodes
    # Stub nodes are basically a container for a Symbol that can have handy predicate
    # methods and operators defined on it since doing so on Symbol will incur the
    # nerdrage of many.
    class Stub < Node
      include PredicateMethods
      include Operators
      include Aliasing
      include Ordering

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

      # We don't want these default Object methods, because if we're
      # calling them we are probably talking about a column name
      [:id, :type].each do |column_method|
        undef_method column_method if method_defined?(column_method) ||
          private_method_defined?(column_method)
      end

      # @return [Symbol] The symbol contained by this stub
      attr_reader :symbol

      # Create a new Stub.
      # @param [Symbol] symbol The symbol that this Stub contains
      def initialize(symbol)
        @symbol = symbol
      end

      # Object comparison
      def eql?(other)
        # Should we maybe allow a stub to equal a symbol?
        # I can see not doing to leading to confusion, but I don't like it. :(
        self.class.eql?(other.class) &&
        self.symbol.eql?(other.symbol)
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
      alias :to_str :to_s

      # @return [Array] An array with a copy of this Stub as the only element.
      def to_a
        [dup]
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
        if args.empty?
          KeyPath.new([self, method_id])
        elsif (args.size == 1) && (Class === args[0])
          KeyPath.new([self, Join.new(method_id, InnerJoin, args[0])])
        else
          KeyPath.new([self, Nodes::Function.new(method_id, args)])
        end
      end

      # Return a KeyPath containing only this Stub, but flagged as absolute.
      # This helps Stubs behave more like a KeyPath, as anyone using the Squeel
      # DSL is likely to think of them as such.
      # @return [KeyPath] An absolute KeyPath, containing only this Stub
      def ~
        KeyPath.new [self], true
      end

      # Create a Function node for a function named the same as this Stub and with the given arguments
      # @return [Function] The new Function node
      def func(*args)
        Function.new(self.symbol, args)
      end

      # Create an inner Join node for the association named by this Stub
      # @return [Join] The new inner Join node
      def inner
        Join.new(self.symbol, InnerJoin)
      end

      # Create a keypath with a sifter as its endpoint
      # @return [KeyPath] The new KeyPath
      def sift(name, *args)
        KeyPath.new([self, Sifter.new(name, args)])
      end

      # Create an outer Join node for the association named by this Stub
      # @return [Join] The new outer Join node
      def outer
        Join.new(self.symbol, OuterJoin)
      end

      # Create a polymorphic Join node for the association named by this Stub,
      # @param [Class] klass The polymorphic belongs_to class for this Join
      # @return [Join] The new polymorphic Join node
      def of_class(klass)
        Join.new(self.symbol, InnerJoin, klass)
      end

      def add_to_tree(hash)
        hash[symbol] ||= {}
      end

    end
  end
end
