module Squeel
  module Nodes
    # A node representing a joined association
    class Join
      # @return [Symbol] The join's association name
      attr_reader :name

      # @return [Arel::InnerJoin, Arel::OuterJoin] The ARel join type
      attr_reader :type

      # @return [Class] The polymorphic belongs_to join class
      # @return [NilClass] If the join is not a polymorphic belongs_to join
      attr_reader :klass

      # Create a new Join node
      # @param [Symbol] name The association name
      # @param [Arel::InnerJoin, Arel::OuterJoin] type The ARel join class
      # @param [Class, String, Symbol] klass The polymorphic belongs_to class or class name
      def initialize(name, type = Arel::InnerJoin, klass = nil)
        @name, @type = name, type
        @klass = convert_to_class(klass) if klass
      end

      # Set the join type to an inner join
      # @return [Join] The join, with an updated join type.
      def inner
        @type = Arel::InnerJoin
        self
      end

      # Set the join type to an outer join
      # @return [Join] The join, with an updated join type.
      def outer
        @type = Arel::OuterJoin
        self
      end

      # Set the polymorphic belongs_to class
      # @param [Class, String, Symbol] class_or_class_name The polymorphic belongs_to class or class name
      # @return [Class] The class that's just been set
      def klass=(class_or_class_name)
        @klass = convert_to_class(class_or_class_name)
      end

      # Returns a true value (the class itself) if a polymorphic belongs_to class has been set
      # @return [NilClass, Class] The class, if present.
      def polymorphic?
        @klass
      end

      # Compare with other objects
      def eql?(other)
        self.class == other.class &&
        self.name  == other.name &&
        self.type == other.type &&
        self.klass == other.klass
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
          KeyPath.new(self, Join.new(method_id, Arel::InnerJoin, args[0]))
        else
          KeyPath.new(self, method_id)
        end
      end

      # expand_hash_conditions_for_aggregates assumes our hash keys can be
      # converted to symbols, so this has to be implemented, but it doesn't
      # really have to do anything useful.
      # @return [NilClass] Just to avoid bombing out on expand_hash_conditions_for_aggregates
      def to_sym
        nil
      end

      private

      # Convert the given value into a class.
      # @param [Class, String, Symbol] value The value to be converted
      # @return [Class] The class after conversion
      def convert_to_class(value)
        case value
        when String, Symbol
          Kernel.const_get(value)
        when Class
          value
        else
          raise ArgumentError, "#{value} cannot be converted to a Class"
        end
      end

    end
  end
end