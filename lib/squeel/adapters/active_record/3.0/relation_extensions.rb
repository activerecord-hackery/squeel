require 'squeel/adapters/active_record/relation_extensions'

module Squeel
  module Adapters
    module ActiveRecord
      module RelationExtensions

        # Returns a JoinDependency for the current relation.
        #
        # We don't need to clear out @join_dependency by overriding #reset,
        # because the default #reset already does this, despite never setting
        # it anywhere that I can find. Serendipity, I say!
        def join_dependency
          @join_dependency ||= (build_join_dependency(table, @joins_values) && @join_dependency)
        end

        # We don't need to call with_default_scope in AR 3.0.x. In fact, since
        # there is no with_default_scope in 3.0.x, that'd be pretty dumb.
        def visited
          clone.visit!
        end

        def build_arel
          arel = table

          arel = build_join_dependency(arel, @joins_values) unless @joins_values.empty?

          arel = collapse_wheres(arel, where_visit((@where_values - ['']).uniq))

          arel = arel.having(*having_visit(@having_values.uniq.reject{|h| h.blank?})) unless @having_values.empty?

          arel = arel.take(connection.sanitize_limit(@limit_value)) if @limit_value
          arel = arel.skip(@offset_value) if @offset_value

          arel = arel.group(*group_visit(@group_values.uniq.reject{|g| g.blank?})) unless @group_values.empty?

          arel = arel.order(*order_visit(@order_values.uniq.reject{|o| o.blank?})) unless @order_values.empty?

          arel = build_select(arel, select_visit(@select_values.uniq))

          arel = arel.from(from_visit(@from_value)) if @from_value
          arel = arel.lock(@lock_value) if @lock_value

          arel
        end

        def build_join_dependency(relation, joins)
          association_joins = []

          joins = joins.map {|j| j.respond_to?(:strip) ? j.strip : j}.uniq

          joins.each do |join|
            association_joins << join if [Hash, Array, Symbol, Nodes::Stub, Nodes::Join, Nodes::KeyPath].include?(join.class) && !array_of_strings?(join)
          end

          stashed_association_joins = joins.grep(::ActiveRecord::Associations::ClassMethods::JoinDependency::JoinAssociation)
          subquery_joins = joins.grep(Nodes::SubqueryJoin)

          non_association_joins = (joins - association_joins - stashed_association_joins - subquery_joins)
          custom_joins = custom_join_sql(*non_association_joins)

          self.join_dependency = JoinDependency.new(@klass, association_joins, custom_joins)

          join_dependency.graft(*stashed_association_joins)

          @implicit_readonly = true unless association_joins.empty? && stashed_association_joins.empty?

          to_join = []

          join_dependency.join_associations.each do |association|
            if (association_relation = association.relation).is_a?(Array)
              to_join << [association_relation.first, association.join_type, association.association_join.first]
              to_join << [association_relation.last, association.join_type, association.association_join.last]
            else
              to_join << [association_relation, association.join_type, association.association_join]
            end
          end

          to_join.uniq.each do |left, join_type, right|
            relation = relation.join(left, join_type).on(*right)
          end

          subquery_joins.each do |join|
            relation = relation.
              join(
                Arel::Nodes::TableAlias.new(
                  join.subquery.right,
                  Arel::Nodes::Grouping.new(join.subquery.left.arel.ast)),
                join.type).
              on(*where_visit(join.constraints))
          end

          relation = relation.join(custom_joins)
        end

        def collapse_wheres(arel, wheres)
          wheres = Array(wheres)
          binaries = wheres.grep(Arel::Nodes::Binary)

          groups = binaries.group_by {|b| [b.class, b.left]}

          groups.each do |_, bins|
            arel = arel.where(Arel::Nodes::And.new(bins))
          end

          (wheres - binaries).each do |where|
            where = Arel.sql(where) if String === where
            arel = arel.where(Arel::Nodes::Grouping.new(where))
          end

          arel
        end

        def where_values_hash_with_squeel
          equalities = find_equality_predicates(where_visit(@where_values))

          Hash[equalities.map { |where| [where.left.name, where.right] }]
        end

        def execute_grouped_calculation(operation, column_name, distinct)
          super
        end

      end
    end
  end
end

ActiveRecord::Relation.send :include, Squeel::Adapters::ActiveRecord::RelationExtensions
