require 'squeel/adapters/active_record/3.1/relation_extensions'

module Squeel
  module Adapters
    module ActiveRecord
      module RelationExtensions
        
        def build_arel
          arel = table.from table

          build_join_dependency(arel, @joins_values) unless @joins_values.empty?

          predicate_viz = predicate_visitor
          attribute_viz = attribute_visitor

          collapse_wheres(arel, predicate_viz.accept((@where_values - ['']).uniq))

          arel.having(*predicate_viz.accept(@having_values.uniq.reject{|h| h.blank?})) unless @having_values.empty?

          arel.take(connection.sanitize_limit(@limit_value)) if @limit_value
          arel.skip(@offset_value) if @offset_value

          arel.group(*attribute_viz.accept(@group_values.uniq.reject{|g| g.blank?})) unless @group_values.empty?

          order = @reorder_value ? @reorder_value : @order_values
          order = attribute_viz.accept(order.uniq.reject{|o| o.blank?})
          order = reverse_sql_order(attrs_to_orderings(order)) if @reverse_order_value
          arel.order(*order) unless order.empty?

          build_select(arel, attribute_viz.accept(@select_values.uniq))
          
          arel.distinct(@uniq_value)
          arel.from(@from_value) if @from_value
          arel.lock(@lock_value) if @lock_value

          arel
        end
        
      end
    end
  end
end