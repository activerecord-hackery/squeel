require 'squeel/adapters/active_record/compat'

module ActiveRecord
  module Associations
    class AssociationScope
      def eval_scope(klass, scope, owner)
        if scope.is_a?(Relation)
          scope
        else
          klass.unscoped.instance_exec(owner, &scope).visited
        end
      end
    end
  end
end
