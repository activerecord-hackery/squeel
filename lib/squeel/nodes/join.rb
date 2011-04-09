module Squeel
  module Nodes
    class Join
      attr_reader :name, :type, :klass

      def initialize(name, type = Arel::InnerJoin, klass = nil)
        @name, @type = name, type
        @klass = convert_to_class(klass) if klass
      end

      def inner
        @type = Arel::InnerJoin
        self
      end

      def outer
        @type = Arel::OuterJoin
        self
      end

      def klass=(class_or_class_name)
        @klass = convert_to_class(class_or_class_name)
      end

      def polymorphic?
        @klass
      end

      # expand_hash_conditions_for_aggregates assumes our hash keys can be
      # converted to symbols, so this has to be implemented, but it doesn't
      # really have to do anything useful.
      def to_sym
        nil
      end

      private

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