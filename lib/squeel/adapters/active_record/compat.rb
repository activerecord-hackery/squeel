module Arel

  module Nodes

    class Grouping < Unary
      include Arel::Predications
    end unless Grouping.include?(Arel::Predications)

  end

  module Visitors

    class DepthFirst < Visitor

      unless method_defined?(:visit_Arel_Nodes_InfixOperation)
        alias :visit_Arel_Nodes_InfixOperation :binary
      end

    end

  end
end
