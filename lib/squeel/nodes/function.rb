module Squeel
  module Nodes
    # A node that represents an SQL function call
    class Function < Node

      include PredicateMethods
      include PredicateOperators
      include Operators
      include Ordering
      include Aliasing

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
      attr_reader :function_name

      # @return [Array] The arguments to be passed to the SQL function
      attr_reader :args

      # Create a node representing an SQL Function with the given name and arguments
      # @param [Symbol] name The function name
      # @param [Array] args The array of arguments to pass to the function.
      def initialize(function_name, args)
        @function_name, @args = function_name, args
      end

      # expand_hash_conditions_for_aggregates assumes our hash keys can be
      # converted to symbols, so this has to be implemented, but it doesn't
      # really have to do anything useful.
      # @return [NilClass] Just to avoid bombing out on expand_hash_conditions_for_aggregates
      def to_sym
        nil
      end

      def hash
        [@name, @args].hash
      end

      def eql?(other)
        self.class == other.class &&
          self.function_name.eql?(other.function_name) &&
          self.args.eql?(other.args)
      end

    end
  end
end
