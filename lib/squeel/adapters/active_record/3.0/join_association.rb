require 'active_record'

module Squeel
  module Adapters
    module ActiveRecord
      class JoinAssociation < ::ActiveRecord::Associations::ClassMethods::JoinDependency::JoinAssociation

        def initialize(reflection, join_dependency, parent = nil, polymorphic_class = nil)
          if polymorphic_class && ::ActiveRecord::Base > polymorphic_class
            swapping_reflection_klass(reflection, polymorphic_class) do |reflection|
              super(reflection, join_dependency, parent)
            end
          else
            super(reflection, join_dependency, parent)
          end
        end

        def swapping_reflection_klass(reflection, klass)
          reflection = reflection.clone
          original_polymorphic = reflection.options.delete(:polymorphic)
          reflection.instance_variable_set(:@klass, klass)
          yield reflection
        ensure
          reflection.options[:polymorphic] = original_polymorphic
        end

        def ==(other)
          super && active_record == other.active_record
        end

        def association_join
          return @join if @Join

          @join = super

          if reflection.macro == :belongs_to && reflection.options[:polymorphic]
            aliased_table = Arel::Table.new(table_name, :as      => @aliased_table_name,
                                                        :engine  => arel_engine,
                                                        :columns => klass.columns)

            parent_table = Arel::Table.new(parent.table_name, :as      => parent.aliased_table_name,
                                                              :engine  => arel_engine,
                                                              :columns => parent.active_record.columns)

            @join << parent_table[reflection.options[:foreign_type]].eq(reflection.klass.name)
          end

          @join
        end

      end
    end
  end
end