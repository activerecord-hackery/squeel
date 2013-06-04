module Squeel
  # Defines the default list of Arel predicates and predicate aliases
  module Constants
    PREDICATES = [
       :eq, :eq_any, :eq_all,
       :not_eq, :not_eq_any, :not_eq_all,
       :matches, :matches_any, :matches_all,
       :does_not_match, :does_not_match_any, :does_not_match_all,
       :lt, :lt_any, :lt_all,
       :lteq, :lteq_any, :lteq_all,
       :gt, :gt_any, :gt_all,
       :gteq, :gteq_any, :gteq_all,
       :in, :in_any, :in_all,
       :not_in, :not_in_any, :not_in_all
     ].freeze

     PREDICATE_ALIASES = {
       :matches        => [:like],
       :does_not_match => [:not_like],
       :lteq           => [:lte],
       :gteq           => [:gte]
     }.freeze
  end
end
