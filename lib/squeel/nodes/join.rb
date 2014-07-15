require 'active_support/core_ext/module'

module Squeel
  module Nodes
    # A node representing a joined association
    class Join < Node
      undef_method :id if method_defined?(:id)

      attr_reader :_join

      delegate :name, :type, :klass, :name=, :type=, :klass=, :to => :_join, :prefix => ''

      # Create a new Join node
      # @param [Symbol] name The association name
      # @param [Arel::InnerJoin, Arel::OuterJoin] type The Arel join class
      # @param [Class, String, Symbol] klass The polymorphic belongs_to class or class name
      def initialize(name, type = InnerJoin, klass = nil)
        @_join = Polyamorous::Join.new(name, type, klass)
      end

      # Set the join type to an inner join
      # @return [Join] The join, with an updated join type.
      def inner
        self._type = InnerJoin
        self
      end

      # Set the join type to an outer join
      # @return [Join] The join, with an updated join type.
      def outer
        self._type = OuterJoin
        self
      end

      def polymorphic?
        _klass
      end

      # Implemented for equality testing
      def hash
        [_name, _type, _klass].hash
      end

      # Compare with other objects
      def eql?(other)
        self.class.eql?(other.class) &&
        self._name.eql?(other._name) &&
        self._type.eql?(other._type) &&
        self._klass.eql?(other._klass)
      end
      alias :== :eql?

      # Ensures that a Join can be used as the base of a new KeyPath
      # @overload node_name
      #   Creates a new KeyPath with this Join as the base and the method_name as the endpoint
      #   @return [KeyPath] The new keypath
      # @overload node_name(klass)
      #   Creates a new KeyPath with this Join as the base and a polymorphic belongs_to join as the endpoint
      #   @param [Class] klass The polymorphic class for the join
      #   @return [KeyPath] The new keypath
      def method_missing(method_id, *args)
        super if method_id == :to_ary
        if (args.size == 1) && (Class === args[0])
          KeyPath.new([self, Join.new(method_id, InnerJoin, args[0])])
        else
          KeyPath.new([self, method_id])
        end
      end

      # Return a KeyPath containing only this Join, but flagged as absolute.
      # This helps Joins behave more like a KeyPath, as anyone using the Squeel
      # DSL is likely to think of them as such.
      # @return [KeyPath] An absolute KeyPath, containing only this Join
      def ~
        KeyPath.new [self], true
      end

      # expand_hash_conditions_for_aggregates assumes our hash keys can be
      # converted to symbols, so this has to be implemented, but it doesn't
      # really have to do anything useful.
      # @return [NilClass] Just to avoid bombing out on expand_hash_conditions_for_aggregates
      def to_sym
        nil
      end

      def add_to_tree(hash)
        hash[_join] ||= {}
      end

    end
  end
end
