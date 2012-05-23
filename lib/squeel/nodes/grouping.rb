module Squeel
  module Nodes
    # A node that represents an SQL function call
    class Grouping < Unary

      include PredicateMethods
      include PredicateOperators
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

