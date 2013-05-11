require 'squeel/adapters/active_record/relation_extensions'

module Squeel
  module Adapters
    module ActiveRecord
      module RelationExtensions

        def where(opts = :chain, *rest)
          if block_given?
            super(DSL.eval &Proc.new)
          else
            super
          end
        end

        def build_arel
          arel = Arel::SelectManager.new(table.engine, table)

          build_joins(arel, joins_values) unless joins_values.empty?

          collapse_wheres(arel, where_visit((where_values - ['']).uniq))

          arel.having(*having_visit(having_values.uniq.reject{|h| h.blank?})) unless having_values.empty?

          arel.take(connection.sanitize_limit(limit_value)) if limit_value
          arel.skip(offset_value.to_i) if offset_value

          arel.group(*group_visit(group_values.uniq.reject{|g| g.blank?})) unless group_values.empty?

          build_order(arel)

          build_select(arel, select_visit(select_values.uniq))

          arel.distinct(distinct_value)
          arel.from(from_visit(from_value)) if from_value
          arel.lock(lock_value) if lock_value

          arel
        end

        def build_order(arel)
          orders = order_visit(dehashified_order_values)
          orders = reverse_sql_order(attrs_to_orderings(orders)) if reverse_order_value

          orders = orders.uniq.reject(&:blank?).flat_map do |order|
            case order
            when Symbol
              table[order].asc
            when Hash
              order.map { |field, dir| table[field].send(dir) }
            else
              order
            end
          end

          arel.order(*orders) unless orders.empty?
        end

        def build_from
          opts, name = from_value
          case opts
          when Relation
            name ||= 'subquery'
            opts.arel.as(name.to_s)
          else
            opts
          end
        end

        private

        def dehashified_order_values
          order_values.map { |o|
            if Hash === o && o.values.all? { |v| [:asc, :desc].include?(v) }
              o.map { |field, dir| table[field].send(dir) }
            else
              o
            end
          }
        end

      end
    end
  end
end

ActiveRecord::Relation.send :include, Squeel::Adapters::ActiveRecord::RelationExtensions
