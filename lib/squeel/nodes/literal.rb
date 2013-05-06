module Squeel
  module Nodes
    # Literal nodes are a container for raw SQL.
    class Literal < Node
      include PredicateMethods
      include PredicateOperators
      include Operators
      include Aliasing
      include Ordering

      attr_reader :expr

      def initialize(expr)
        @expr = expr
      end

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

      # Object comparison
      def eql?(other)
        self.class.eql?(other.class) &&
        self.expr.eql?(other.expr)
      end

      # To support object equality tests
      def hash
        expr.hash
      end

      # expand_hash_conditions_for_aggregates assumes our hash keys can be
      # converted to symbols, so this has to be implemented, but it doesn't
      # really have to do anything useful.
      # @return [NilClass] Just to avoid bombing out on expand_hash_conditions_for_aggregates
      def to_sym
        nil
      end

      # @return [String] The Literal's String equivalent.
      def to_s
        expr.to_s
      end
      alias :to_str :to_s

    end
  end
end
