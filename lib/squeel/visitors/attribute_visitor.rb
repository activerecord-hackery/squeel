require 'squeel/visitors/visitor'

module Squeel
  module Visitors
    # A visitor that tries to convert visited nodes into Arel::Attributes
    # or other nodes that can be used for grouping, ordering, and the like.
    class AttributeVisitor < Visitor

      private

      # Visit a Hash. This entails iterating through each key and value and
      # visiting each value in turn.
      #
      # @param [Hash] o The Hash to visit
      # @param parent The current parent object in the context
      # @return [Array] An array of values for use in an ordering, grouping, etc.
      def visit_Hash(o, parent)
        o.map do |k, v|
          if implies_context_change?(v)
            visit_with_context_change(k, v, parent)
          else
            visit_without_context_change(k, v, parent)
          end
        end.flatten
      end

      # Visit elements of an array that it's possible to visit -- leave other
      # elements untouched.
      #
      # @param [Array] o The array to visit
      # @param parent The array's parent within the context
      # @return [Array] The flattened array with elements visited
      def visit_Array(o, parent)
        o.map { |v| can_visit?(v) ? visit(v, parent) : v }.flatten
      end

      # Visit a symbol. This will return an attribute named after the symbol against
      # the current parent's contextualized table.
      #
      # @param [Symbol] o The symbol to visit
      # @param parent The symbol's parent within the context
      # @return [Arel::Attribute] An attribute on the contextualized parent table
      def visit_Symbol(o, parent)
        contextualize(parent)[o]
      end

      # Visit a stub. This will return an attribute named after the stub against
      # the current parent's contextualized table.
      #
      # @param [Nodes::Stub] o The stub to visit
      # @param parent The stub's parent within the context
      # @return [Arel::Attribute] An attribute on the contextualized parent table
      def visit_Squeel_Nodes_Stub(o, parent)
        contextualize(parent)[o.symbol]
      end

      # Visit a Literal by converting it to an ARel SqlLiteral
      #
      # @param [Nodes::Literal] o The Literal to visit
      # @param parent The parent object in the context (unused)
      # @return [Arel::Nodes::SqlLiteral] An SqlLiteral
      def visit_Squeel_Nodes_Literal(o, parent)
        Arel.sql(o.expr)
      end

      # Visit a keypath. This will traverse the keypath's "path", setting a new
      # parent as though the keypath's endpoint was in a deeply-nested hash,
      # then visit the endpoint with the new parent.
      #
      # @param [Nodes::KeyPath] o The keypath to visit
      # @param parent The keypath's parent within the context
      # @return The visited endpoint, with the parent from the KeyPath's path.
      def visit_Squeel_Nodes_KeyPath(o, parent)
        parent = traverse(o, parent)

        visit(o.endpoint, parent)
      end

      # Visit an Order node.
      #
      # @param [Nodes::Order] o The order node to visit
      # @param parent The node's parent within the context
      # @return [Arel::Nodes::Ordering] An ascending or desending ordering
      def visit_Squeel_Nodes_Order(o, parent)
        visit(o.expr, parent).send(o.descending? ? :desc : :asc)
      end

      # Visit a Function node. Each function argument will be visiteded or
      # contextualized if appropriate. Keep in mind that this occurs with
      # the current parent within the context.
      #
      # @example A function as the endpoint of a keypath
      #   Person.joins{children}.order{children.coalesce(name, '<no name>')}
      #   # => SELECT "people".* FROM "people"
      #          INNER JOIN "people" "children_people"
      #            ON "children_people"."parent_id" = "people"."id"
      #          ORDER BY coalesce("children_people"."name", '<no name>')
      #
      # @param [Nodes::Function] o The function node to visit
      # @param parent The node's parent within the context
      def visit_Squeel_Nodes_Function(o, parent)
        args = o.args.map do |arg|
          case arg
          when Nodes::Function, Nodes::KeyPath, Nodes::As, Nodes::Literal
            visit(arg, parent)
          when Symbol, Nodes::Stub
            Arel.sql(arel_visitor.accept contextualize(parent)[arg.to_sym])
          else
            quote arg
          end
        end
        func = Arel::Nodes::NamedFunction.new(o.name, args)

        o.alias ? func.as(o.alias) : func
      end

      # Visit an Operation node. Each operand will be accepted or
      # contextualized if appropriate. Keep in mind that this occurs with
      # the current parent within the context.
      #
      # @param [Nodes::Operation] o The operation node to visit
      # @param parent The node's parent within the context
      def visit_Squeel_Nodes_Operation(o, parent)
        args = o.args.map do |arg|
          case arg
          when Nodes::Function, Nodes::KeyPath, Nodes::As, Nodes::Literal
            visit(arg, parent)
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
          Arel.sql("#{arel_visitor.accept(args[0])} #{o.operator} #{arel_visitor.accept(args[1])}")
        end
        o.alias ? op.as(o.alias) : op
      end

      # Visit a Squeel Grouping node, resulting in am ARel Grouping node.
      #
      # @param [Nodes::Grouping] The Grouping node to visit
      # @param parent The parent object in the context
      # @return [Arel::Nodes::Grouping] The resulting grouping node.
      def visit_Squeel_Nodes_Grouping(o, parent)
        Arel::Nodes::Grouping.new(visit(o.expr, parent))
      end

      # Visit a Squeel As node, resulting in am ARel As node.
      #
      # @param [Nodes::As] The As node to visit
      # @param parent The parent object in the context
      # @return [Arel::Nodes::As] The resulting as node.
      def visit_Squeel_Nodes_As(o, parent)
        visit(o.left, parent).as(o.right)
      end

      # Visit an ActiveRecord Relation, returning an Arel::SelectManager
      # @param [ActiveRecord::Relation] o The Relation to visit
      # @param parent The parent object in the context
      # @return [Arel::SelectManager] The ARel select manager that represents
      #   the relation's query
      def visit_ActiveRecord_Relation(o, parent)
        o.arel
      end

      # @return [Boolean] Whether the given value implies a context change
      # @param v The value to consider
      def implies_context_change?(v)
        can_visit?(v)
      end

      # Change context (by setting the new parent to the result of a #find or
      # #traverse on the key), then accept the given value.
      #
      # @param k The hash key
      # @param v The hash value
      # @param parent The current parent object in the context
      # @return The visited value
      def visit_with_context_change(k, v, parent)
        parent = case k
          when Nodes::KeyPath
            traverse(k, parent, true)
          else
            find(k, parent)
          end

        if Array === v
          v.map {|val| visit(val, parent || k)}
        else
          can_visit?(v) ? visit(v, parent || k) : v
        end
      end

      # If there is no context change, we'll just return the value unchanged,
      # currently. Is this really the right behavior? I don't think so, but
      # it works in this case.
      #
      # @param k The hash key
      # @param v The hash value
      # @param parent The current parent object in the context
      # @return The same value we just received. Yeah, this method's pretty pointless,
      #   for now, and only here for consistency's sake.
      def visit_without_context_change(k, v, parent)
        v
      end

    end
  end
end
