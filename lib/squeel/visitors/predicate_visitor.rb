require 'squeel/visitors/visitor'

module Squeel
  module Visitors
    class PredicateVisitor < Visitor

      TRUE_SQL = Arel.sql('1=1').freeze
      FALSE_SQL = Arel.sql('1=0').freeze

      private

      # Visit a Hash. This entails iterating through each key and value and
      # visiting each value in turn.
      #
      # @param [Hash] o The Hash to visit
      # @param parent The current parent object in the context
      # @return [Array] An array of values for use in a where or having clause
      def visit_Hash(o, parent)
        predicates = o.map do |k, v|
          if implies_hash_context_shift?(v)
            visit_with_hash_context_shift(k, v, parent)
          else
            visit_without_hash_context_shift(k, v, parent)
          end
        end

        predicates.flatten!

        if predicates.size > 1
          Arel::Nodes::Grouping.new(Arel::Nodes::And.new predicates)
        else
          predicates.first
        end
      end

      # Visit ActiveRecord::Base objects. These should be converted to their
      # id before being used in a comparison.
      #
      # @param [ActiveRecord::Base] o The AR::Base object to visit
      # @param parent The current parent object in the context
      # @return [Fixnum] The id of the object
      def visit_ActiveRecord_Base(o, parent)
        o.id
      end

      # Visit a KeyPath by traversing the path and then visiting the endpoint.
      #
      # @param [Nodes::KeyPath] o The KeyPath to visit
      # @param parent The parent object in the context
      # @return The visited endpoint, in the context of the KeyPath's path
      def visit_Squeel_Nodes_KeyPath(o, parent)
        parent = traverse(o, parent)

        visit(o.endpoint, parent)
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

      # Visit a Stub by converting it to an ARel attribute
      #
      # @param [Nodes::Stub] o The Stub to visit
      # @param parent The parent object in the context
      # @return [Arel::Attribute] An attribute of the parent table with the
      #   Stub's column
      def visit_Squeel_Nodes_Stub(o, parent)
        contextualize(parent)[o.to_s]
      end

      # Visit a Literal by converting it to an ARel SqlLiteral
      #
      # @param [Nodes::Literal] o The Literal to visit
      # @param parent The parent object in the context (unused)
      # @return [Arel::Nodes::SqlLiteral] An SqlLiteral
      def visit_Squeel_Nodes_Literal(o, parent)
        Arel.sql(o.expr)
      end

      # Visit a Squeel sifter by executing its corresponding constraint block
      # in the parent's class, with its given arguments, then visiting the result.
      #
      # @param [Nodes::Sifter] o The Sifter to visit
      # @param parent The parent object in the context
      # @return The result of visiting the executed block's return value
      def visit_Squeel_Nodes_Sifter(o, parent)
        klass = classify(parent)
        visit(klass.send(o.name, *o.args), parent)
      end

      # Visit a Squeel predicate, converting it into an ARel predicate
      #
      # @param [Nodes::Predicate] o The predicate to visit
      # @param parent The parent object in the context
      # @return An ARel predicate node
      #   (Arel::Nodes::Equality, Arel::Nodes::Matches, etc)
      def visit_Squeel_Nodes_Predicate(o, parent)
        value = o.value

        case value
        when Nodes::KeyPath
          value = can_visit?(value.endpoint) ? visit(value, parent) : contextualize(traverse(value, parent))[value.endpoint.to_s]
        when ActiveRecord::Relation
          value = visit(
            value.select_values.empty? ? value.select(value.klass.arel_table[value.klass.primary_key]) : value,
            parent
          )
        else
          value = visit(value, parent) if can_visit?(value)
        end

        value = quote_for_node(o.expr, value)

        attribute = case o.expr
        when Nodes::Stub, Nodes::Function, Nodes::Literal, Nodes::Grouping
          visit(o.expr, parent)
        else
          contextualize(parent)[o.expr]
        end

        if Array === value && [:in, :not_in].include?(o.method_name)
          o.method_name == :in ? attribute_in_array(attribute, value) : attribute_not_in_array(attribute, value)
        else
          attribute.send(o.method_name, value)
        end
      end

      # Visit a Squeel function, returning an ARel NamedFunction node.
      #
      # @param [Nodes::Function] o The function node to visit
      # @param parent The parent object in the context
      # @return [Arel::Nodes::NamedFunction] A named function node. Function
      #   arguments are visited, if necessary, before being passed to the NamedFunction.
      def visit_Squeel_Nodes_Function(o, parent)
        args = o.args.map do |arg|
          case arg
          when Nodes::Function, Nodes::As, Nodes::Literal, Nodes::Grouping
            visit(arg, parent)
          when ActiveRecord::Relation
            arg.arel.ast
          when Nodes::KeyPath
            can_visit?(arg.endpoint) ? visit(arg, parent) : contextualize(traverse(arg, parent))[arg.endpoint.to_s]
          when Symbol, Nodes::Stub
            Arel.sql(arel_visitor.accept contextualize(parent)[arg.to_s])
          else
            quote arg
          end
        end
        func = Arel::Nodes::NamedFunction.new(o.name, args)

        o.alias ? func.as(o.alias) : func
      end

      # Visit an ActiveRecord Relation, returning an Arel::SelectManager
      # @param [ActiveRecord::Relation] o The Relation to visit
      # @param parent The parent object in the context
      # @return [Arel::SelectManager] The ARel select manager that represents
      #   the relation's query
      def visit_ActiveRecord_Relation(o, parent)
        o.arel
      end

      # Visit a Squeel operation node, convering it to an ARel InfixOperation
      # (or subclass, as appropriate)
      #
      # @param [Nodes::Operation] o The Operation node to visit
      # @param parent The parent object in the context
      # @return [Arel::Nodes::InfixOperation] The InfixOperation (or Addition,
      #   Multiplication, etc) node, with both operands visited, if needed.
      def visit_Squeel_Nodes_Operation(o, parent)
        args = o.args.map do |arg|
          case arg
          when Nodes::Function, Nodes::As, Nodes::Literal, Nodes::Grouping
            visit(arg, parent)
          when Nodes::KeyPath
            can_visit?(arg.endpoint) ? visit(arg, parent) : contextualize(traverse(arg, parent))[arg.endpoint.to_s]
          when Symbol, Nodes::Stub
            Arel.sql(arel_visitor.accept contextualize(parent)[arg.to_s])
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
          Arel::Nodes::InfixOperation.new(o.operator, args[0], args[1])
        end
        o.alias ? op.as(o.alias) : op
      end

      # Visit a Squeel And node, returning an ARel Grouping containing an
      # ARel And node.
      #
      # @param [Nodes::And] o The And node to visit
      # @param parent The parent object in the context
      # @return [Arel::Nodes::Grouping] A grouping node, containnig an ARel
      #   And node as its expression. All children will be visited before
      #   being passed to the And.
      def visit_Squeel_Nodes_And(o, parent)
        Arel::Nodes::Grouping.new(Arel::Nodes::And.new(visit(o.children, parent)))
      end

      # Visit a Squeel Or node, returning an ARel Or node.
      #
      # @param [Nodes::Or] o The Or node to visit
      # @param parent The parent object in the context
      # @return [Arel::Nodes::Or] An ARel Or node, with left and right sides visited
      def visit_Squeel_Nodes_Or(o, parent)
        Arel::Nodes::Grouping.new(Arel::Nodes::Or.new(visit(o.left, parent), (visit(o.right, parent))))
      end

      # Visit a Squeel Not node, returning an ARel Not node.
      #
      # @param [Nodes::Not] o The Not node to visit
      # @param parent The parent object in the context
      # @return [Arel::Nodes::Not] An ARel Not node, with expression visited
      def visit_Squeel_Nodes_Not(o, parent)
        Arel::Nodes::Not.new(visit(o.expr, parent))
      end

      # Visit a Squeel Grouping node, returning an ARel Grouping node.
      #
      # @param [Nodes::Grouping] o The Grouping node to visit
      # @param parent The parent object in the context
      # @return [Arel::Nodes::Grouping] An ARel Grouping node, with expression visited
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

      # Change context (by setting the new parent to the result of a #find or
      # #traverse on the key), then accept the given value.
      #
      # @param k The hash key
      # @param v The hash value
      # @param parent The current parent object in the context
      # @return The visited value
      def visit_with_hash_context_shift(k, v, parent)
        @hash_context_depth += 1

        parent = case k
          when Nodes::KeyPath
            traverse(k, parent, true)
          else
            find(k, parent)
          end

        case v
        when Hash, Nodes::KeyPath, Nodes::Predicate, Nodes::Unary, Nodes::Binary, Nodes::Nary, Nodes::Sifter
          visit(v, parent || k)
        when Array
          v.map {|val| visit(val, parent || k)}
        else
          raise ArgumentError, <<-END
          Hashes, Predicates, and arrays of visitables as values imply that their
          corresponding keys are a parent. This didn't work out so well in the case
          of key = #{k} and value = #{v}"
          END
        end
      ensure
        @hash_context_depth -= 1
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
          visit(k % quote_for_node(k.expr, v), parent)
        when Nodes::Function, Nodes::Literal
          arel_predicate_for(visit(k, parent), quote(v), parent)
        when Nodes::KeyPath
          visit(k % quote_for_node(k.endpoint, v), parent)
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

      # Determine whether to use IN or equality testing for a predicate,
      # based on its value class, then return the appropriate predicate.
      #
      # @param attribute The ARel attribute (or function/operation) the
      #   predicate will be created for
      # @param value The value to be compared against
      # @return [Arel::Nodes::Node] An ARel predicate node
      def arel_predicate_for(attribute, value, parent)
        if ActiveRecord::Relation === value && value.select_values.empty?
          value = visit(value.select(value.klass.arel_table[value.klass.primary_key]), parent)
        else
          value = can_visit?(value) ? visit(value, parent) : value
        end

        case value
        when Array
          attribute_in_array(attribute, value)
        when Range, Arel::SelectManager
          attribute.in(value)
        else
          attribute.eq(value)
        end
      end

      def attribute_in_array(attribute, array)
        if array.empty?
          FALSE_SQL
        elsif array.include? nil
          array = array.compact
          array.empty? ? attribute.eq(nil) : attribute.in(array).or(attribute.eq nil)
        else
          attribute.in array
        end
      end

      def attribute_not_in_array(attribute, array)
        if array.empty?
          TRUE_SQL
        elsif array.include? nil
          array = array.compact
          array.empty? ? attribute.not_eq(nil) : attribute.not_in(array).and(attribute.not_eq nil)
        else
          attribute.not_in array
        end
      end

      # Certain nodes require us to do the quoting before the ARel
      # visitor gets a chance to try, because we want to avoid having our
      # values quoted as a type of the last visited column. Otherwise, we
      # can end up with annoyances like having "joe" quoted to 0, if the
      # last visited column was of an integer type.
      #
      # @param node The node we (might) be quoting for
      # @param v The value to (possibly) quote
      def quote_for_node(node, v)
        case node
        when Nodes::Function, Nodes::Literal
          quote(v)
        when Nodes::Predicate
          quote_for_node(node.expr, v)
        else
          v
        end
      end

    end
  end
end
