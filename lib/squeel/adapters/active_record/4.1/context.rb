require 'squeel/adapters/active_record/context'

module Squeel
  module Adapters
    module ActiveRecord
      class Context < ::Squeel::Context
        class NoParentFoundError < RuntimeError; end

        def initialize(object)
          super
          @base = object.join_root
          @engine = @base.base_klass.arel_engine
          @arel_visitor = get_arel_visitor
          @default_table = Arel::Table.new(@base.table_name, :as => @base.aliased_table_name, :engine => @engine)
        end

        def find(object, parent = @base)
          if ::ActiveRecord::Associations::JoinDependency::JoinPart === parent
            case object
            when String, Symbol, Nodes::Stub
              assoc_name = object.to_s
              find_string_symbol_stub_association(@base.children, @base, assoc_name, parent)
            when Nodes::Join
              find_node_join_association(@base.children, @base, object, parent)
            else
              find_other_association(@base.children, @base, object, parent)
            end
          end
        end

        def find!(object, parent = @base)
          if ::ActiveRecord::Associations::JoinDependency::JoinPart === parent
            result =
              case object
                when String, Symbol, Nodes::Stub
                  assoc_name = object.to_s
                  find_string_symbol_stub_association(@base.children, @base, assoc_name, parent)
                when Nodes::Join
                  find_node_join_association(@base.children, @base, object, parent)
                else
                  find_other_association(@base.children, @base, object, parent)
                end

            result || raise(NoParentFoundError, "can't find #{object} in #{parent}")
          else
            raise NoParentFoundError, "can't find #{object} in #{parent}"
          end
        end

        def traverse!(keypath, parent = @base, include_endpoint = false)
          parent = @base if keypath.absolute?
          keypath.path_without_endpoint.each do |key|
            parent = find!(key, parent)
          end
          parent = find!(keypath.endpoint, parent) if include_endpoint

          parent
        end

        private
          def find_string_symbol_stub_association(join_associations, current_parent, assoc_name, target_parent)
            join_associations.each do |assoc|
              return assoc if assoc.reflection.name.to_s == assoc_name && current_parent.equal?(target_parent)
              child_assoc = find_string_symbol_stub_association(assoc.children, assoc, assoc_name, target_parent)
              return child_assoc if child_assoc
            end && false
          end

          def find_node_join_association(join_associations, current_parent, object, target_parent)
            join_associations.each do |assoc|
              return assoc if assoc.reflection.name == object._name && current_parent.equal?(target_parent) &&
                (object.polymorphic? ? assoc.reflection.klass == object._klass : true)
              child_assoc = find_node_join_association(assoc.children, assoc, object, target_parent)
              return child_assoc if child_assoc
            end && false
          end

          def find_other_association(join_associations, current_parent, object, target_parent)
            join_associations.each do |assoc|
              return assoc if assoc.reflection == object && current_parent.equal?(target_parent)
              child_assoc = find_other_association(assoc.children, assoc, object, target_parent)
              return child_assoc if child_assoc
            end && false
          end
      end
    end
  end
end
