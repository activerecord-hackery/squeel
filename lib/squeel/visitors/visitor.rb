require 'active_support/core_ext/module'
require 'squeel/nodes'

module Squeel
  module Visitors
    # The Base visitor class, containing the default behavior common to subclasses.
    class Visitor
      attr_accessor :context
      delegate :contextualize, :classify, :find, :traverse, :engine, :arel_visitor, :find!, :traverse!, :to => :context

      # Create a new Visitor that uses the supplied context object to contextualize
      # visited nodes.
      #
      # @param [Context] context The context to use for node visitation.
      def initialize(context = nil)
        @context = context
        @hash_context_depth = 0
      end

      # Accept an object.
      #
      # @param object The object to visit
      # @param parent The parent of this object, to track the object's place in
      #   any association hierarchy.
      # @return The results of the node visitation, typically an Arel object of some kind.
      def accept(object, parent = context.base)
        visit(object, parent)
      end

      def accept!(object, parent = context.base)
        visit!(object, parent)
      end

      # @param object The object to check
      # @return [Boolean] Whether or not the visitor can visit the given object
      def can_visit?(object)
        self.class.can_visit? object
      end

      # @param object The object to check
      # @return [Boolean] Whether or not visitors of this class can visit the given object
      def self.can_visit?(object)
        @can_visit ||= Hash.new do |hash, klass|
          hash[klass] = klass.ancestors.detect { |ancestor|
            private_method_defined? DISPATCH[ancestor]
          } ? true : false
        end
        @can_visit[object.class]
      end

      private

      def symbolify(o)
        case o
        when Symbol, String, Nodes::Stub
          o.to_sym
        else
          nil
        end
      end

      # A hash that caches the method name to use for a visitor for a given class
      DISPATCH = Hash.new do |hash, klass|
        hash[klass] = "visit_#{(klass.name || '').gsub('::', '_')}"
      end

      # If we're visiting stuff in a hash, it's good to check whether or
      # not we've shifted context already. If we have, we may want to use
      # caution as it pertains to certain input, in case it's untrusted.
      # See CVE-2012-2661 for info.
      #
      # @return [Boolean] Whether we're within a new context.
      def hash_context_shifted?
        @hash_context_depth > 0
      end

      # @return [Boolean] Whether the given value implies a context change
      # @param v The value to consider
      def implies_hash_context_shift?(v)
        can_visit?(v)
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

        can_visit?(v) ? visit(v, parent || k) : v
      ensure
        @hash_context_depth -= 1
      end

      def visit_with_hash_context_shift!(k, v, parent)
        @hash_context_depth += 1

        parent = case k
          when Nodes::KeyPath
            traverse!(k, parent, true)
          else
            find!(k, parent)
          end

        can_visit?(v) ? visit!(v, parent || k) : v
      ensure
        @hash_context_depth -= 1
      end

      # If there is no context change, the default behavior is to return the
      # value unchanged. Subclasses will alter this behavior as needed.
      #
      # @param k The hash key
      # @param v The hash value
      # @param parent The current parent object in the context
      # @return The same value we just received.
      def visit_without_hash_context_shift(k, v, parent)
        v
      end

      # Important to avoid accidentally allowing the default Arel visitor's
      # last_column quoting behavior (where a value is quoted as though it
      # is of the type of the last visited column). This can wreak havoc with
      # Functions and Operations.
      #
      # @param object The object to check
      # @return [Boolean] Whether or not the Arel visitor will try to quote the
      #   object if not passed as an SqlLiteral.
      def quoted?(object)
        case object
        when Arel::Nodes::SqlLiteral, Bignum, Fixnum,
          Arel::SelectManager
          false
        when NilClass
          defined?(Arel::Nodes::Quoted) ? true : false
        else
          true
        end
      end

      # Quote a value based on its type, not on the last column used by the
      # Arel visitor. This is occasionally necessary to avoid having Arel
      # quote a value according to an integer column, converting 'My String' to 0.
      #
      # @param value The value to quote
      # @return [Arel::Nodes::SqlLiteral] if the value needs to be pre-quoted
      # @return the unquoted value, if default quoting won't hurt.
      def quote(value)
        if quoted? value
          case value
          when Array
            value.map {|v| quote(v)}
          when Range
            Range.new(quote(value.begin), quote(value.end), value.exclude_end?)
          else
            if defined?(Arel::Collectors::SQLString)
              Arel.sql(arel_visitor.compile(Arel::Nodes.build_quoted(value)))
            else
              Arel.sql(arel_visitor.accept value)
            end
          end
        else
          value
        end
      end

      # Visit the object.
      #
      # @param object The object to visit
      # @param parent The object's parent within the context
      def visit(object, parent)
        send(DISPATCH[object.class], object, parent)
      rescue NoMethodError => e
        raise e if respond_to?(DISPATCH[object.class], true)

        superklass = object.class.ancestors.find { |klass|
          respond_to?(DISPATCH[klass], true)
        }
        raise(TypeError, "Cannot visit #{object.class}") unless superklass
        DISPATCH[object.class] = DISPATCH[superklass]
        retry
      end

      def visit!(object, parent)
        send("#{DISPATCH[object.class]}!", object, parent)
      rescue NoMethodError => e
        visit(object, parent)
      end

      # Pass an object through the visitor unmodified. This is
      # in order to allow objects that don't require modification
      # to be handled by Arel directly.
      #
      # @param object The object to visit
      # @param parent The object's parent within the context
      # @return The object, unmodified
      def visit_passthrough(object, parent)
        object
      end

      alias :visit_Fixnum :visit_passthrough
      alias :visit_Bignum :visit_passthrough

      # Visit an array, which involves accepting any values we know how to
      # accept, and skipping the rest.
      #
      # @param [Array] o The Array to visit
      # @param parent The current parent object in the context
      # @return [Array] The visited array
      def visit_Array(o, parent)
        o.map { |v| can_visit?(v) ? visit(v, parent) : v }.flatten
      end

      def visit_Array!(o, parent)
        o.map { |v| can_visit?(v) ? visit!(v, parent) : v }.flatten
      end

      # Visit a Hash. This entails iterating through each key and value and
      # visiting each value in turn.
      #
      # @param [Hash] o The Hash to visit
      # @param parent The current parent object in the context
      # @return [Array] An array of values for use in an ordering, grouping, etc.
      def visit_Hash(o, parent)
        o.map do |k, v|
          if implies_hash_context_shift?(v)
            visit_with_hash_context_shift(k, v, parent)
          else
            visit_without_hash_context_shift(k, v, parent)
          end
        end.flatten
      end

      def visit_Hash!(o, parent)
        o.map do |k, v|
          if implies_hash_context_shift?(v)
            visit_with_hash_context_shift!(k, v, parent)
          else
            visit_without_hash_context_shift(k, v, parent)
          end
        end.flatten
      end

      # Visit a symbol. This will return an attribute named after the symbol
      # against the current parent's contextualized table.
      #
      # @param [Symbol] o The symbol to visit
      # @param parent The symbol's parent within the context
      # @return [Arel::Attribute] An attribute on the contextualized parent
      #   table
      def visit_Symbol(o, parent)
        contextualize(parent)[o]
      end

      # Visit a stub. This will return an attribute named after the stub against
      # the current parent's contextualized table.
      #
      # @param [Nodes::Stub] o The stub to visit
      # @param parent The stub's parent within the context
      # @return [Arel::Attribute] An attribute on the contextualized parent
      #   table
      def visit_Squeel_Nodes_Stub(o, parent)
        contextualize(parent)[o.to_s]
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

      def visit_Squeel_Nodes_KeyPath!(o, parent)
        parent = traverse!(o, parent)

        visit!(o.endpoint, parent)
      end

      # Visit a Literal by converting it to an Arel SqlLiteral
      #
      # @param [Nodes::Literal] o The Literal to visit
      # @param parent The parent object in the context (unused)
      # @return [Arel::Nodes::SqlLiteral] An SqlLiteral
      def visit_Squeel_Nodes_Literal(o, parent)
        Arel.sql(o.expr)
      end

      # Visit a Squeel As node, resulting in am Arel As node.
      #
      # @param [Nodes::As] The As node to visit
      # @param parent The parent object in the context
      # @return [Arel::Nodes::As] The resulting as node.
      def visit_Squeel_Nodes_As(o, parent)
        # patch for 4+, binds params using native to_sql before transforms to sql string
        if ::ActiveRecord::VERSION::MAJOR >= 4 && o.left.is_a?(::ActiveRecord::Relation)
          Arel::Nodes::TableAlias.new(
            Arel::Nodes::Grouping.new(
              Arel::Nodes::SqlLiteral.new(
                o.left.respond_to?(:to_sql_with_binding_params) ? o.left.to_sql_with_binding_params : o.left.to_sql
              )
            ),
            o.right
          )
        else
          left = visit(o.left, parent)
          # Some nodes, like Arel::SelectManager, have their own #as methods,
          # with behavior that we don't want to clobber.
          if left.respond_to?(:as)
            left.as(o.right)
          else
            Arel::Nodes::As.new(left, o.right)
          end
        end
      end

      # Visit a Squeel And node, returning an Arel Grouping containing an
      # Arel And node.
      #
      # @param [Nodes::And] o The And node to visit
      # @param parent The parent object in the context
      # @return [Arel::Nodes::Grouping] A grouping node, containnig an Arel
      #   And node as its expression. All children will be visited before
      #   being passed to the And.
      def visit_Squeel_Nodes_And(o, parent)
        Arel::Nodes::Grouping.new(Arel::Nodes::And.new(visit(o.children, parent)))
      end

      # Visit a Squeel Or node, returning an Arel Or node.
      #
      # @param [Nodes::Or] o The Or node to visit
      # @param parent The parent object in the context
      # @return [Arel::Nodes::Or] An Arel Or node, with left and right sides visited
      def visit_Squeel_Nodes_Or(o, parent)
        Arel::Nodes::Grouping.new(Arel::Nodes::Or.new(visit(o.left, parent), (visit(o.right, parent))))
      end

      # Visit a Squeel Not node, returning an Arel Not node.
      #
      # @param [Nodes::Not] o The Not node to visit
      # @param parent The parent object in the context
      # @return [Arel::Nodes::Not] An Arel Not node, with expression visited
      def visit_Squeel_Nodes_Not(o, parent)
        Arel::Nodes::Not.new(visit(o.expr, parent))
      end

      # Visit a Squeel Grouping node, returning an Arel Grouping node.
      #
      # @param [Nodes::Grouping] o The Grouping node to visit
      # @param parent The parent object in the context
      # @return [Arel::Nodes::Grouping] An Arel Grouping node, with expression visited
      def visit_Squeel_Nodes_Grouping(o, parent)
        Arel::Nodes::Grouping.new(visit(o.expr, parent))
      end
      #
      # Visit a Squeel function, returning an Arel NamedFunction node.
      #
      # @param [Nodes::Function] o The function node to visit
      # @param parent The parent object in the context
      # @return [Arel::Nodes::NamedFunction] A named function node. Function
      #   arguments are visited, if necessary, before being passed to the NamedFunction.
      def visit_Squeel_Nodes_Function(o, parent)
        args = o.args.map do |arg|
          case arg
          when Nodes::Function, Nodes::As, Nodes::Literal, Nodes::Grouping, Nodes::KeyPath
            visit(arg, parent)
          when ActiveRecord::Relation
            arg.arel.ast
          when Symbol, Nodes::Stub
            if defined?(Arel::Collectors::SQLString)
              Arel.sql(arel_visitor.compile(contextualize(parent)[arg.to_s]))
            else
              Arel.sql(arel_visitor.accept(contextualize(parent)[arg.to_s]))
            end
          else
            quote arg
          end
        end

        Arel::Nodes::NamedFunction.new(o.function_name.to_s, args)
      end

      # Visit a Squeel operation node, convering it to an Arel InfixOperation
      # (or subclass, as appropriate)
      #
      # @param [Nodes::Operation] o The Operation node to visit
      # @param parent The parent object in the context
      # @return [Arel::Nodes::InfixOperation] The InfixOperation (or Addition,
      #   Multiplication, etc) node, with both operands visited, if needed.
      def visit_Squeel_Nodes_Operation(o, parent)
        args = o.args.map do |arg|
          case arg
          when Nodes::Function, Nodes::As, Nodes::Literal, Nodes::Grouping, Nodes::KeyPath
            visit(arg, parent)
          when Symbol, Nodes::Stub
            if defined?(Arel::Collectors::SQLString)
              Arel.sql(arel_visitor.compile(contextualize(parent)[arg.to_s]))
            else
              Arel.sql(arel_visitor.accept(contextualize(parent)[arg.to_s]))
            end
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

        op
      end

      # Visit an Active Record Relation, returning an Arel::SelectManager
      # @param [ActiveRecord::Relation] o The Relation to visit
      # @param parent The parent object in the context
      # @return [Arel::SelectManager] The Arel select manager that represents
      #   the relation's query
      def visit_ActiveRecord_Relation(o, parent)
        o.arel
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

      def visit_Arel_Nodes_Node(o, parent)
        o
      end

    end
  end
end
