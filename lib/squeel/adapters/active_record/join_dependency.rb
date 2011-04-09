require 'active_record'

module Squeel
  module Adapters
    module ActiveRecord
      module JoinDependency

        # Yes, I'm using alias_method_chain here. No, I don't feel too
        # bad about it. JoinDependency, or, to call it by its full proper
        # name, ::ActiveRecord::Associations::JoinDependency, is one of the
        # most "for internal use only" chunks of ActiveRecord.
        def self.included(base)
          base.class_eval do
            alias_method_chain :build, :squeel
          end
        end

        def build_with_squeel(associations, parent = nil, join_type = Arel::InnerJoin)
          associations = associations.symbol if Nodes::Stub === associations

          case associations
          when Nodes::Join
            parent ||= join_parts.last
            reflection = parent.reflections[associations.name] or
              raise ::ActiveRecord::ConfigurationError, "Association named '#{ associations.name }' was not found; perhaps you misspelled it?"

            unless join_association = find_join_association_respecting_polymorphism(reflection, parent, associations)
              @reflections << reflection
              join_association = build_join_association_respecting_polymorphism(reflection, parent, associations)
              join_association.join_type = associations.type
              @join_parts << join_association
              cache_joined_association(join_association)
            end

            join_association
          when Nodes::KeyPath
            parent ||= join_parts.last
            associations.path_with_endpoint.each do |key|
              parent = build(key, parent, join_type)
            end
            parent
          else
            build_without_squeel(associations, parent, join_type)
          end
        end

        def find_join_association_respecting_polymorphism(reflection, parent, join)
          if association = find_join_association(reflection, parent)
            unless reflection.options[:polymorphic]
              association
            else
              association if association.active_record == join.klass
            end
          end
        end

        def build_join_association_respecting_polymorphism(reflection, parent, join)
          if reflection.options[:polymorphic] && join.polymorphic?
            JoinAssociation.new(reflection, self, parent, join.klass)
          else
            JoinAssociation.new(reflection, self, parent)
          end
        end

      end
    end
  end
end