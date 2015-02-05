require 'squeel/adapters/active_record/4.1/relation_extensions'

module Squeel
  module Adapters
    module ActiveRecord
      module RelationExtensions

        undef_method 'to_sql_with_binding_params'

        attr_accessor :reverse_order_value
        private :reverse_order_value, :reverse_order_value=

        # We are using 4.1 version of reverse_order!
        # Because 4.2 reverse the order immediately before build_order
        def reverse_order!
          self.reverse_order_value = !reverse_order_value
          self
        end

        def build_arel
          arel = Arel::SelectManager.new(table.engine, table)

          build_joins(arel, joins_values.flatten) unless joins_values.empty?

          collapse_wheres(arel, where_visit((where_values - ['']).uniq))

          arel.having(*having_visit(having_values.uniq.reject(&:blank?))) unless having_values.empty?

          arel.take(connection.sanitize_limit(limit_value)) if limit_value
          arel.skip(offset_value.to_i) if offset_value
          arel.group(*group_visit(group_values.uniq.reject(&:blank?))) unless group_values.empty?

          build_order(arel)

          build_select(arel)

          arel.distinct(distinct_value)
          arel.from(build_from) if from_value
          arel.lock(lock_value) if lock_value

          arel
        end

        def build_join_dependency(manager, joins)
          buckets = joins.group_by do |join|
            case join
            when String
              :string_join
            when Hash, Symbol, Array, Nodes::Stub, Nodes::Join, Nodes::KeyPath
              :association_join
            when ::ActiveRecord::Associations::JoinDependency
              :stashed_join
            when Arel::Nodes::Join
              :join_node
            when Nodes::SubqueryJoin
              :subquery_join
            else
              raise 'unknown class: %s' % join.class.name
            end
          end

          association_joins         = buckets[:association_join] || []
          stashed_association_joins = buckets[:stashed_join] || []
          join_nodes                = (buckets[:join_node] || []).uniq
          subquery_joins            = buckets[:subquery_join] || []
          string_joins              = (buckets[:string_join] || []).map { |x|
            x.strip
          }.uniq

          join_list = join_nodes + custom_join_ast(manager, string_joins)

          # All of that duplication just to do this...
          self.join_dependency = ::ActiveRecord::Associations::JoinDependency.new(
            @klass,
            association_joins,
            join_list
          )

          self.stashed_join_dependencies = stashed_association_joins

          join_infos = join_dependency.join_constraints stashed_association_joins

          join_infos.each do |info|
            info.joins.each { |join| manager.from(join) }
            manager.bind_values.concat info.binds
          end

          manager.join_sources.concat(join_list)
          manager.join_sources.concat(build_join_from_subquery(subquery_joins))

          manager
        end

        alias :build_joins :build_join_dependency

        def where_values_hash_with_squeel(relation_table_name = table_name)
          equalities = find_equality_predicates(where_visit(where_values), relation_table_name)

          binds = Hash[bind_values.find_all(&:first).map { |column, v| [column.name, v] }]

          Hash[equalities.map { |where|
            name = where.left.name
            [name, binds.fetch(name.to_s) {
              case where.right
              when Array then where.right.map(&:val)
              else
                where.right.val
              end
            }]
          }]
        end

        def expand_attrs_from_hash(opts)
          opts = ::ActiveRecord::PredicateBuilder.resolve_column_aliases(klass, opts)

          tmp_opts, bind_values = create_binds(opts)
          self.bind_values += bind_values

          attributes = @klass.send(:expand_hash_conditions_for_aggregates, tmp_opts)
          attributes.values.grep(::ActiveRecord::Relation) do |rel|
            self.bind_values += rel.bind_values
          end

          attributes
        end
      end
    end
  end
end

ActiveRecord::Relation.send :include, Squeel::Adapters::ActiveRecord::RelationExtensions
