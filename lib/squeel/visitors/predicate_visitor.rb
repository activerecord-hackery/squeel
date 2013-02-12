require 'squeel/visitors/visitor'
require 'squeel/visitors/predicate_visitation'

module Squeel
  module Visitors
    class PredicateVisitor < Visitor
      include PredicateVisitation

      private

      # Visit a Hash. This entails iterating through each key and value and
      # visiting each value in turn.
      #
      # @param [Hash] o The Hash to visit
      # @param parent The current parent object in the context
      # @return [Array] An array of values for use in a where or having clause
      def visit_Hash(o, parent)
        predicates = super

        if predicates.size > 1
          Arel::Nodes::Grouping.new(Arel::Nodes::And.new predicates)
        else
          predicates.first
        end
      end


      # @return [Boolean] Whether the given value implies a context change
      # @param v The value to consider
      def implies_hash_context_shift?(v)
        case v
        when Hash, Nodes::Predicate, Nodes::Unary, Nodes::Binary, Nodes::Nary, Nodes::Sifter
          true
        when Nodes::KeyPath
          can_visit?(v.endpoint) && !(Nodes::Stub === v.endpoint)
        else
          false
        end
      end

      # Create a predicate for a given key/value pair. If the value is
      # a Symbol, Stub, or KeyPath, it's converted to a table.column for
      # the predicate value.
      #
      # @param k The hash key
      # @param v The hash value
      # @param parent The current parent object in the context
      # @return An ARel predicate
      def visit_without_hash_context_shift(k, v, parent)
        case v
        when Nodes::Stub, Symbol
          v = contextualize(parent)[v.to_s]
        when Nodes::KeyPath # If we could visit the endpoint, we wouldn't be here
          v = contextualize(traverse(v, parent))[v.endpoint.to_s]
        end

        case k
        when Nodes::Predicate
          visit(k % quote_for_node(v, k.expr, parent), parent)
        when Nodes::Function, Nodes::Literal
          arel_predicate_for(visit(k, parent), quote(v), parent)
        when Nodes::KeyPath
          visit(k % quote_for_node(v, k.endpoint, parent), parent)
        else
          attr_name = k.to_s
          attribute = if !hash_context_shifted? && attr_name.include?('.')
              table_name, attr_name = attr_name.split(/\./, 2)
              Arel::Table.new(table_name.to_s, :engine => engine)[attr_name.to_s]
            else
              contextualize(parent)[attr_name]
            end
          arel_predicate_for(attribute, v, parent)
        end
      end

    end
  end
end
