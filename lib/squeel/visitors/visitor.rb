require 'active_support/core_ext/module'
require 'squeel/nodes'

module Squeel
  module Visitors
    # The Base visitor class, containing the default behavior common to subclasses.
    class Visitor
      attr_accessor :context
      delegate :contextualize, :classify, :find, :traverse, :engine, :arel_visitor, :to => :context

      # Create a new Visitor that uses the supplied context object to contextualize
      # visited nodes.
      #
      # @param [Context] context The context to use for node visitation.
      def initialize(context = nil)
        @context = context
      end

      # Accept an object.
      #
      # @param object The object to visit
      # @param parent The parent of this object, to track the object's place in
      #   any association hierarchy.
      # @return The results of the node visitation, typically an ARel object of some kind.
      def accept(object, parent = context.base)
        visit(object, parent)
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

      # A hash that caches the method name to use for a visitor for a given class
      DISPATCH = Hash.new do |hash, klass|
        hash[klass] = "visit_#{(klass.name || '').gsub('::', '_')}"
      end

      # Important to avoid accidentally allowing the default ARel visitor's
      # last_column quoting behavior (where a value is quoted as though it
      # is of the type of the last visited column). This can wreak havoc with
      # Functions and Operations.
      #
      # @param object The object to check
      # @return [Boolean] Whether or not the ARel visitor will try to quote the object if
      #   not passed as an SqlLiteral.
      def quoted?(object)
        case object
        when Arel::Nodes::SqlLiteral, Bignum, Fixnum, Arel::SelectManager
          false
        else
          true
        end
      end

      # Quote a value based on its type, not on the last column used by the
      # ARel visitor. This is occasionally necessary to avoid having ARel
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
            Arel.sql(arel_visitor.accept value)
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

      # Visit an array, which involves accepting any values we know how to
      # accept, and skipping the rest.
      #
      # @param [Array] o The Array to visit
      # @param parent The current parent object in the context
      # @return [Array] The visited array
      def visit_Array(o, parent)
        o.map { |v| can_visit?(v) ? visit(v, parent) : v }.flatten
      end

      # Pass an object through the visitor unmodified. This is
      # in order to allow objects that don't require modification
      # to be handled by ARel directly.
      #
      # @param object The object to visit
      # @param parent The object's parent within the context
      # @return The object, unmodified
      def visit_passthrough(object, parent)
        object
      end
      alias :visit_Fixnum :visit_passthrough
      alias :visit_Bignum :visit_passthrough

    end
  end
end
