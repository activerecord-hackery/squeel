require 'squeel/visitors/base'

module Squeel
  module Visitors
    class PredicateVisitor < Base

      private

      def visit_Hash(o, parent)
        predicates = o.map do |k, v|
          if implies_context_change?(v)
            visit_with_context_change(k, v, parent)
          else
            visit_without_context_change(k, v, parent)
          end
        end

        predicates.flatten!

        if predicates.size > 1
          Arel::Nodes::Grouping.new(Arel::Nodes::And.new predicates)
        else
          predicates.first
        end
      end

      def visit_Array(o, parent)
        o.map { |v| can_accept?(v) ? accept(v, parent) : v }.flatten
      end

      def visit_Squeel_Nodes_KeyPath(o, parent)
        parent = traverse(o, parent)

        accept(o.endpoint, parent)
      end

      def visit_Squeel_Nodes_Stub(o, parent)
        contextualize(parent)[o.symbol]
      end

      def visit_Squeel_Nodes_Predicate(o, parent)
        value = o.value
        if Nodes::KeyPath === value
          value = can_accept?(value.endpoint) ? accept(value, parent) : contextualize(traverse(value, parent))[value.endpoint.to_sym]
        else
          value = accept(value, parent) if can_accept?(value)
        end

        case o.expr
        when Nodes::Stub
          accept(o.expr, parent).send(o.method_name, value)
        when Nodes::Function
          accept(o.expr, parent).send(o.method_name, quote(value))
        else
          contextualize(parent)[o.expr].send(o.method_name, value)
        end
      end

      def visit_Squeel_Nodes_Function(o, parent)
        args = o.args.map do |arg|
          case arg
          when Nodes::Function
            accept(arg, parent)
          when Nodes::KeyPath
            can_accept?(arg.endpoint) ? accept(arg, parent) : contextualize(traverse(arg, parent))[arg.endpoint.to_sym]
          when Symbol, Nodes::Stub
            Arel.sql(arel_visitor.accept contextualize(parent)[arg.to_sym])
          else
            quote arg
          end
        end
        Arel::Nodes::NamedFunction.new(o.name, args, o.alias)
      end

      def visit_ActiveRecord_Relation(o, parent)
        o.arel
      end

      def visit_Squeel_Nodes_Operation(o, parent)
        args = o.args.map do |arg|
          case arg
          when Nodes::Function
            accept(arg, parent)
          when Nodes::KeyPath
            can_accept?(arg.endpoint) ? accept(arg, parent) : contextualize(traverse(arg, parent))[arg.endpoint.to_sym]
          when Symbol, Nodes::Stub
            Arel.sql(arel_visitor.accept contextualize(parent)[arg.to_sym])
          else
            quote arg
          end
        end

        op = case o.operator
        when :+
          Arel::Nodes::Addition.new(args[0], args[1])
        when :-
          Arel::Nodes::Subtraction.new(args[0], args[1])
        when :*
          Arel::Nodes::Multiplication.new(args[0], args[1])
        when :/
          Arel::Nodes::Division.new(args[0], args[1])
        else
          Arel::Nodes::InfixOperation(o.operator, args[0], args[1])
        end
        o.alias ? op.as(o.alias) : op
      end

      def visit_Squeel_Nodes_And(o, parent)
        Arel::Nodes::Grouping.new(Arel::Nodes::And.new(accept(o.children, parent)))
      end

      def visit_Squeel_Nodes_Or(o, parent)
        accept(o.left, parent).or(accept(o.right, parent))
      end

      def visit_Squeel_Nodes_Not(o, parent)
        accept(o.expr, parent).not
      end

      def implies_context_change?(v)
        case v
        when Hash, Nodes::Predicate, Nodes::Unary, Nodes::Binary, Nodes::Nary
          true
        when Nodes::KeyPath
          can_accept?(v.endpoint) && !(Nodes::Stub === v.endpoint)
        when Array
          (!v.empty? && v.all? {|val| can_accept?(val)})
        else
          false
        end
      end

      def visit_with_context_change(k, v, parent)
        parent = case k
          when Nodes::KeyPath
            traverse(k, parent, true)
          else
            find(k, parent)
          end

        case v
        when Hash, Nodes::KeyPath, Nodes::Predicate, Nodes::Unary, Nodes::Binary, Nodes::Nary
          accept(v, parent || k)
        when Array
          v.map {|val| accept(val, parent || k)}
        else
          raise ArgumentError, <<-END
          Hashes, Predicates, and arrays of visitables as values imply that their
          corresponding keys are a parent. This didn't work out so well in the case
          of key = #{k} and value = #{v}"
          END
        end
      end

      def visit_without_context_change(k, v, parent)
        case v
        when Nodes::Stub, Symbol
          v = contextualize(parent)[v.to_sym]
        when Nodes::KeyPath # If we could accept the endpoint, we wouldn't be here
          v = contextualize(traverse(v, parent))[v.endpoint.to_sym]
        end

        case k
        when Nodes::Predicate
          accept(k % quote_for_node(k.expr, v), parent)
        when Nodes::Function
          arel_predicate_for(accept(k, parent), quote(v), parent)
        when Nodes::KeyPath
          accept(k % quote_for_node(k.endpoint, v), parent)
        else
          attribute = contextualize(parent)[k.to_sym]
          arel_predicate_for(attribute, v, parent)
        end
      end

      def arel_predicate_for(attribute, value, parent)
        if [Array, Range, Arel::SelectManager].include?(value.class)
          attribute.in(value)
        else
          value = can_accept?(value) ? accept(value, parent) : value
          attribute.eq(value)
        end
      end

      def quote_for_node(node, v)
        case node
        when Nodes::Function
          quote(v)
        when Nodes::Predicate
          Nodes::Function === node.expr ? quote(v) : v
        else
          v
        end
      end

    end
  end
end