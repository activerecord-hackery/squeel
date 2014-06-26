module Squeel
  module Adapters
    module ActiveRecord
      module JoinAssociationExtensions

        # Should it been put into polyamorous gem?
        def self.included(base)
          base.class_eval do
            attr_reader :join_type
            alias_method_chain :initialize, :squeel
          end
        end

        def initialize_with_squeel(reflection, children, polymorphic_class = nil, join_type = Arel::Nodes::InnerJoin)
          @join_type = join_type
          initialize_without_squeel(reflection, children, polymorphic_class)
        end
      end

      ::ActiveRecord::Associations::JoinDependency::JoinAssociation.send(:include, JoinAssociationExtensions)
    end
  end
end
