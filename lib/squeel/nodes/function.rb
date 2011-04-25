require 'squeel/predicate_methods'

module Squeel
  module Nodes
    # A node that represents an SQL function call
    class Function

      include PredicateMethods
      include Operators

      # @return [Symbol] The name of the SQL function to be called
      attr_reader :name

      # @return [Array] The arguments to be passed to the SQL function
      attr_reader :args

      # @return [String] The SQL function's alias
      # @return [NilClass] If no alias
      attr_reader :alias

      # Create a node representing an SQL Function with the given name and arguments
      # @param [Symbol] name The function name
      # @param [Array] args The array of arguments to pass to the function.
      def initialize(name, args)
        @name, @args = name, args
      end

      # Set an alias for the function
      # @param [String, Symbol] The alias name
      # @return [Function] This function with the new alias value.
      def as(alias_name)
        @alias = alias_name.to_s
        self
      end

      def asc
        Order.new self, 1
      end

      def desc
        Order.new self, -1
      end

      def ==(value)
        Predicate.new self, :eq, value
      end

      # Won't work on Ruby 1.8.x so need to do this conditionally
      define_method('!=') do |value|
        Predicate.new(self, :not_eq, value)
      end if respond_to?('!=')

      def ^(value)
        Predicate.new self, :not_eq, value
      end

      def >>(value)
        Predicate.new self, :in, value
      end

      def <<(value)
        Predicate.new self, :not_in, value
      end

      def =~(value)
        Predicate.new self, :matches, value
      end

      # Won't work on Ruby 1.8.x so need to do this conditionally
      define_method('!~') do |value|
        Predicate.new(self, :does_not_match, value)
      end if respond_to?('!~')

      def >(value)
        Predicate.new self, :gt, value
      end

      def >=(value)
        Predicate.new self, :gteq, value
      end

      def <(value)
        Predicate.new self, :lt, value
      end

      def <=(value)
        Predicate.new self, :lteq, value
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