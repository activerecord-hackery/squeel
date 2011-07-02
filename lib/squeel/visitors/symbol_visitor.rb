require 'squeel/visitors/base'

module Squeel
  module Visitors
    class SymbolVisitor < Base

      def initialize
      end

      def accept(object, parent = nil)
        visit(object, parent)
      end

      private

      def visit_Array(o, parent)
        o.map {|e| visit(e, parent)}.flatten
      end

      def visit_Hash(o, parent)
        {}.tap do |hash|
          o.each do |key, value|
            hash[visit(key, parent)] = visit(value, parent)
          end
        end
      end

      def visit_Symbol(o, parent)
        o
      end

      def visit_Squeel_Nodes_Stub(o, parent)
        o.symbol
      end

      def visit_Squeel_Nodes_KeyPath(o, parent)
        o.path_with_endpoint.reverse.map(&:to_sym).inject do |hash, key|
          {key => hash}
        end
      end

      def visit_Squeel_Nodes_Join(o, parent)
        o._name
      end

    end
  end
end