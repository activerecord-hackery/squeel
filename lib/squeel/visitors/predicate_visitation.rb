module Squeel
  module Visitors
    module PredicateVisitation

      private

      TRUE_SQL = Arel.sql('1=1').freeze
      FALSE_SQL = Arel.sql('1=0').freeze

      # Visit a Squeel sifter by executing its corresponding constraint block
      # in the parent's class, with its given arguments, then visiting the
      # result.
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

        value = quote_for_node(value, o.expr, parent)

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
          value = quote_for_attribute(value, attribute)
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
      # @param v The value to (possibly) quote
      # @param node The node we (might) be quoting for
      # @param parent The parent of the node being quoted for
      def quote_for_node(v, node, parent)
        case node
        when Nodes::Function, Nodes::Literal
          quote(v)
        when Nodes::Predicate
          quote_for_node(v, node.expr, parent)
        when Symbol, Nodes::Stub # MySQL hates freedom
          quote_for_attribute v, visit(node, parent)
        else
          v
        end
      end

      # Because MySQL hates doing sane things, we are forced to try to quote
      # certain values for a specific column type. Otherwise, MySQL might
      # "helpfully" cast the column we're checking to the type we're comparing
      # it to, resulting in such wonderful queries as...
      #
      #   SELECT * FROM table WHERE str_column = 0
      #
      # ...returning every record in the table that doesn't have a number in
      # str_column.
      #
      # Everything about this method is awful. 2 x private method calls to ARel,
      # wrapping a pre-quoted value in an SqlLiteral... Everything. My only
      # solace is that I think we can fix it in ARel in the longer term.
      def quote_for_attribute(v, attr)
        case v
        when Array
          v.map { |v| quote_for_attribute(v, attr) }
        when Range
          Range.new(
            quote_for_attribute(v.begin, attr),
            quote_for_attribute(v.end, attr),
            v.exclude_end?
          )
        when Bignum, Fixnum, Integer, ActiveSupport::Duration
          column = arel_visitor.send(:column_for, attr)
          Arel::Nodes::SqlLiteral.new arel_visitor.send(:quote, v, column)
        else
          v
        end
      end

    end
  end
end
