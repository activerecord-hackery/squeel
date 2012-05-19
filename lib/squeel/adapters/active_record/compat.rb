module Arel
  module Nodes
    class Grouping < Unary
      include Arel::Predications
    end unless Grouping.include?(Arel::Predications)
  end
end
