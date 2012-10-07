require 'squeel/adapters/active_record/relation_extensions'

module Squeel
  module Adapters
    module ActiveRecord
      module RelationExtensions

        def build_arel
          arel = table.from table

          build_join_dependency(arel, @joins_values) unless @joins_values.empty?

          collapse_wheres(arel, where_visit((@where_values - ['']).uniq))

          arel.having(*having_visit(@having_values.uniq.reject{|h| h.blank?})) unless @having_values.empty?

          arel.take(connection.sanitize_limit(@limit_value)) if @limit_value
          arel.skip(@offset_value) if @offset_value

          arel.group(*group_visit(@group_values.uniq.reject{|g| g.blank?})) unless @group_values.empty?

          order = order_visit(@order_values.uniq)
          order = reverse_sql_order(attrs_to_orderings(order)) if @reverse_order_value
          arel.order(*order.uniq.reject{|o| o.blank?}) unless order.empty?

          build_select(arel, select_visit(@select_values.uniq))

          arel.distinct(@uniq_value)
          arel.from(from_visit(@from_value)) if @from_value
          arel.lock(@lock_value) if @lock_value

          arel
        end

      end
    end
  end
end

ActiveRecord::Relation.send :include, Squeel::Adapters::ActiveRecord::RelationExtensions
