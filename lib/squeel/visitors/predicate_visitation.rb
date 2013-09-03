module Squeel
  module Visitors
    module PredicateVisitation
      EXPAND_BELONGS_TO_METHODS = [:eq, :not_eq]

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
        visit(klass.send("sifter_#{o.name}", *o.args), parent)
      end

      # Visit a Squeel predicate, converting it into an Arel predicate
      #
      # @param [Nodes::Predicate] o The predicate to visit
      # @param parent The parent object in the context
      # @return An Arel predicate node
      #   (Arel::Nodes::Equality, Arel::Nodes::Matches, etc)
      def visit_Squeel_Nodes_Predicate(o, parent)
        value = o.value

        # Short-circuit for stuff like `where{ author.eq User.first }`
        # This filthy hack emulates similar behavior in AR PredicateBuilder
        if ActiveRecord::Base === value &&
          EXPAND_BELONGS_TO_METHODS.include?(o.method_name) &&
          association = classify(parent).reflect_on_association(
            symbolify(o.expr)
          )
          return expand_belongs_to(o, parent, association)
        end

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

      # Determine whether to use IN or equality testing for a predicate,
      # based on its value class, then return the appropriate predicate.
      #
      # @param attribute The Arel attribute (or function/operation) the
      #   predicate will be created for
      # @param value The value to be compared against
      # @return [Arel::Nodes::Node] An Arel predicate node
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

      # Certain nodes require us to do the quoting before the Arel
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
