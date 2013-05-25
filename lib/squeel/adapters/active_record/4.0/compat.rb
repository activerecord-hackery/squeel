require 'squeel/adapters/active_record/compat'

module ActiveRecord
  module Associations
    class AssociationScope
      # 4.0's eval_scope doesn't play nicely with different bases. Need to do
      # a similar workaround to the one for AR::Relation#merge, visiting it
      def eval_scope(klass, scope)
        if scope.is_a?(Relation)
          scope
        else
          klass.unscoped.instance_exec(owner, &scope).visited
        end
      end
    end
  end
end
