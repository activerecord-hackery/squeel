require 'squeel/context'

module Squeel
  module Adapters
    module ActiveRecord
      class Context < ::Squeel::Context
        # Because the AR::Associations namespace is insane
        JoinPart = ::ActiveRecord::Associations::JoinDependency::JoinPart

        def initialize(object)
          super
          @base = object.join_base
          @engine = @base.arel_engine
          @arel_visitor = @engine.connection.visitor
          @default_table = Arel::Table.new(@base.table_name, :as => @base.aliased_table_name, :engine => @engine)
        end

        def find(object, parent = @base)
          if JoinPart === parent
            object = object.to_sym if String === object
            case object
            when Symbol, Nodes::Stub
              @object.join_associations.detect { |j|
                j.reflection.name == object.to_sym && j.parent == parent
              }
            when Nodes::Join
              @object.join_associations.detect { |j|
                j.reflection.name == object.name && j.parent == parent &&
                (object.polymorphic? ? j.reflection.klass == object._klass : true)
              }
            else
              @object.join_associations.detect { |j|
                j.reflection == object && j.parent == parent
              }
            end
          end
        end

        def traverse(keypath, parent = @base, include_endpoint = false)
          parent = @base if keypath.absolute?
          keypath.path.each do |key|
            parent = find(key, parent) || key
          end
          parent = find(keypath.endpoint, parent) if include_endpoint

          parent
        end

        private

        def get_table(object)
          if [Symbol, String, Nodes::Stub].include?(object.class)
            Arel::Table.new(object.to_sym, :engine => @engine)
          elsif Nodes::Join === object
            object._klass ? object._klass.arel_table : Arel::Table.new(object._name, :engine => @engine)
          elsif object.respond_to?(:aliased_table_name)
            Arel::Table.new(object.table_name, :as => object.aliased_table_name, :engine => @engine)
          else
            raise ArgumentError, "Unable to get table for #{object}"
          end
        end

      end
    end
  end
end