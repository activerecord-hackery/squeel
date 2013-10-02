require 'active_support/core_ext/module'
require 'squeel/nodes'

module Squeel
  module Visitors
    # The Enumeration visitor class, used to implement Node#each
    class EnumerationVisitor

      # Create a new EnumerationVisitor.
      #
      # @param [Proc] block The block to execute against each node.
      def initialize(block = Proc.new)
        @block = block
      end

      # Accept an object.
      #
      # @param object The object to visit
      # @return The results of the node visitation, which will be the last
      #   call to the @block
      def accept(object)
        visit(object)
      end

      private
      # A hash that caches the method name to use for a visitor for a given
      # class
      DISPATCH = Hash.new do |hash, klass|
        hash[klass] = "visit_#{(klass.name || '').gsub('::', '_')}"
      end

      # Visit the object.
      #
      # @param object The object to visit
      def visit(object)
        send(DISPATCH[object.class], object)
        @block.call(object)
      rescue NoMethodError => e
        raise e if respond_to?(DISPATCH[object.class], true)

        superklass = object.class.ancestors.find { |klass|
          respond_to?(DISPATCH[klass], true)
        }
        raise(TypeError, "Cannot visit #{object.class}") unless superklass
        DISPATCH[object.class] = DISPATCH[superklass]
        retry
      end

      def visit_terminal(o)
      end
      alias :visit_Object :visit_terminal

      def visit_Array(o)
        o.map { |v| visit(v) }
      end

      def visit_Hash(o)
        o.each { |k, v| visit(k); visit(v) }
      end

      def visit_Squeel_Nodes_Nary(o)
        visit(o.children)
      end

      def visit_Squeel_Nodes_Binary(o)
        visit(o.left)
        visit(o.right)
      end

      def visit_Squeel_Nodes_Unary(o)
        visit(o.expr)
      end

      def visit_Squeel_Nodes_Order(o)
        visit(o.expr)
      end

      def visit_Squeel_Nodes_Function(o)
        visit(o.args)
      end

      def visit_Squeel_Nodes_Predicate(o)
        visit(o.expr)
        visit(o.value)
      end

      def visit_Squeel_Nodes_KeyPath(o)
        visit(o.path)
      end

      def visit_Squeel_Nodes_Join(o)
        visit(o._join)
      end

      def visit_Squeel_Nodes_Literal(o)
        visit(o.expr)
      end

    end
  end
end
