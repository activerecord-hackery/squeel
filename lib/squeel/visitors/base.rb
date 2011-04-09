require 'active_support/core_ext/module'
require 'squeel/nodes'

module Squeel
  module Visitors
    class Base
      attr_accessor :context
      delegate :contextualize, :find, :traverse, :sanitize_sql, :engine, :arel_visitor, :to => :context

      def initialize(context = nil)
        @context = context
      end

      def accept(object, parent = context.base)
        visit(object, parent)
      end

      def can_accept?(object)
        respond_to? DISPATCH[object.class]
      end

      def self.can_accept?(object)
        method_defined? DISPATCH[object.class]
      end

      private

      DISPATCH = Hash.new do |hash, klass|
        hash[klass] = "visit_#{klass.name.gsub('::', '_')}"
      end

      def quoted?(object)
        case object
        when Arel::Nodes::SqlLiteral, Bignum, Fixnum
          false
        else
          true
        end
      end

      def visit(object, parent)
        send(DISPATCH[object.class], object, parent)
      end
    end
  end
end