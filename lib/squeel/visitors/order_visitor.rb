module Squeel
  module Visitors
    class OrderVisitor < Visitor
      include PredicateVisitation

      private

      # Visit an Order node.
      #
      # @param [Nodes::Order] o The order node to visit
      # @param parent The node's parent within the context
      # @return [Arel::Nodes::Ordering] An ascending or desending ordering
      def visit_Squeel_Nodes_Order(o, parent)
        if defined?(Arel::Nodes::Descending)
          if o.descending?
            Arel::Nodes::Descending.new(visit(o.expr, parent))
          else
            Arel::Nodes::Ascending.new(visit(o.expr, parent))
          end
        else
          visit(o.expr, parent).send(o.descending? ? :desc : :asc)
        end
      end
    end
  end
end

