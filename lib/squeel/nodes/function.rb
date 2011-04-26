require 'squeel/predicate_methods'

module Squeel
  module Nodes
    # A node that represents an SQL function call
    class Function

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