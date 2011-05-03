require 'active_support/core_ext/module'
require 'squeel/nodes'

module Squeel
  module Visitors
    # The Base visitor class, containing the default behavior common to subclasses.
    class Base
      attr_accessor :context
      delegate :contextualize, :find, :traverse, :engine, :arel_visitor, :to => :context

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
      # @return [Boolean] Whether or not the visitor can accept the given object
      def can_accept?(object)
        self.class.can_accept? object
      end

      # @param object The object to check
      # @return [Boolean] Whether or not visitors of this class can accept the given object
      def self.can_accept?(object)
        @can_accept ||= Hash.new do |hash, klass|
          hash[klass] = klass.ancestors.detect { |ancestor|
            private_method_defined? DISPATCH[ancestor]
          } ? true : false
        end
        @can_accept[object.class]
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
        when Arel::Nodes::SqlLiteral, Bignum, Fixnum
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

      # Visit the object. This is not called directly, but instead via the public
      # #accept method.
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

    end
  end
end