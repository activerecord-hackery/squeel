require 'active_record'

module Squeel
  module Adapters
    module ActiveRecord
      module RelationExtensions

        JoinAssociation = ::ActiveRecord::Associations::JoinDependency::JoinAssociation
        JoinDependency = ::ActiveRecord::Associations::JoinDependency

        attr_writer :join_dependency
        private :join_dependency=

        # Returns a JoinDependency for the current relation.
        #
        # We don't need to clear out @join_dependency by overriding #reset, because
        # the default #reset already does this, despite never setting it anywhere that
        # I can find. Serendipity, I say!
        def join_dependency
          @join_dependency ||= (build_join_dependency(table.from(table), @joins_values) && @join_dependency)
        end

        def predicate_visitor
          Visitors::PredicateVisitor.new(
            Context.new(join_dependency)
          )
        end

        def attribute_visitor
          Visitors::AttributeVisitor.new(
            Context.new(join_dependency)
          )
        end

        # We need to be able to support merging two relations that have a different
        # base class. Stock ActiveRecord doesn't have to do anything too special, because
        # it's already created predicates out of the where_values by now, and they're
        # already bound to the proper table.
        #
        # Squeel, on the other hand, needs to do its best to ensure the predicates are still
        # winding up against the proper table. The most "correct" way I can think of to do
        # this is to try to emulate the default AR behavior -- that is, de-squeelifying
        # the *_values, erm... values by visiting them and converting them to ARel nodes
        # before merging. Merging relations is a nifty little trick, but it's another
        # little corner of ActiveRecord where the magic quickly fades. :(
        def merge(r)
          if relation_with_different_base?(r)
            r = r.clone.visit!
          end

          super(r)
        end

        def relation_with_different_base?(r)
          ::ActiveRecord::Relation === r &&
          base_class.name != r.klass.base_class.name
        end

        def prepare_relation_for_association_merge!(r, association_name)
          r.where_values.map! {|w| Squeel::Visitors::PredicateVisitor.can_visit?(w) ? {association_name => w} : w}
          r.having_values.map! {|h| Squeel::Visitors::PredicateVisitor.can_visit?(h) ? {association_name => h} : h}
          r.group_values.map! {|g| Squeel::Visitors::AttributeVisitor.can_visit?(g) ? {association_name => g} : g}
          r.order_values.map! {|o| Squeel::Visitors::AttributeVisitor.can_visit?(o) ? {association_name => o} : o}
          r.select_values.map! {|s| Squeel::Visitors::AttributeVisitor.can_visit?(s) ? {association_name => s} : s}
          r.joins_values.map! {|j| [Symbol, Hash, Nodes::Stub, Nodes::Join, Nodes::KeyPath].include?(j.class) ? {association_name => j} : j}
          r.includes_values.map! {|i| [Symbol, Hash, Nodes::Stub, Nodes::Join, Nodes::KeyPath].include?(i.class) ? {association_name => i} : i}
        end

        def visit!
          predicate_viz = predicate_visitor
          attribute_viz = attribute_visitor

          @where_values = predicate_viz.accept((@where_values - ['']).uniq)
          @having_values = predicate_viz.accept(@having_values.uniq.reject{|h| h.blank?})
          @group_values = attribute_viz.accept(@group_values.uniq.reject{|g| g.blank?})
          @order_values = attribute_viz.accept(@order_values.uniq.reject{|o| o.blank?})
          @select_values = attribute_viz.accept(@select_values.uniq)

          self
        end

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

          arel.from(@from_value) if @from_value
          arel.lock(@lock_value) if @lock_value

          arel
        end

        # reverse_sql_order will reverse the order of strings or Orderings,
        # but not attributes
        def attrs_to_orderings(order)
          order.map do |o|
            Arel::Attribute === o ? o.asc : o
          end
        end

        def build_join_dependency(manager, joins)
          buckets = joins.group_by do |join|
            case join
            when String
              'string_join'
            when Hash, Symbol, Array, Nodes::Stub, Nodes::Join, Nodes::KeyPath
              'association_join'
            when JoinAssociation
              'stashed_join'
            when Arel::Nodes::Join
              'join_node'
            else
              raise 'unknown class: %s' % join.class.name
            end
          end

          association_joins         = buckets['association_join'] || []
          stashed_association_joins = buckets['stashed_join'] || []
          join_nodes                = (buckets['join_node'] || []).uniq
          string_joins              = (buckets['string_join'] || []).map { |x|
            x.strip
          }.uniq

          join_list = join_nodes + custom_join_ast(manager, string_joins)

          # All of that duplication just to do this...
          self.join_dependency = JoinDependency.new(
            @klass,
            association_joins,
            join_list
          )

          join_dependency.graft(*stashed_association_joins)

          @implicit_readonly = true unless association_joins.empty? && stashed_association_joins.empty?

          join_dependency.join_associations.each do |association|
            association.join_to(manager)
          end

          manager.join_sources.concat join_list

          manager
        end

        def includes(*args)
          if block_given? && args.empty?
            super(DSL.eval &Proc.new)
          else
            super
          end
        end

        def preload(*args)
          if block_given? && args.empty?
            super(DSL.eval &Proc.new)
          else
            super
          end
        end

        def eager_load(*args)
          if block_given? && args.empty?
            super(DSL.eval &Proc.new)
          else
            super
          end
        end

        def select(value = Proc.new)
          if block_given? && Proc === value
            if value.arity > 0
              to_a.select {|*block_args| value.call(*block_args)}
            else
              relation = clone
              relation.select_values += Array.wrap(DSL.eval &value)
              relation
            end
          else
            super
          end
        end

        def group(*args)
          if block_given? && args.empty?
            super(DSL.eval &Proc.new)
          else
            super
          end
        end

        def order(*args)
          if block_given? && args.empty?
            super(DSL.eval &Proc.new)
          else
            super
          end
        end

        def reorder(*args)
          if block_given? && args.empty?
            super(DSL.eval &Proc.new)
          else
            super
          end
        end

        def joins(*args)
          if block_given? && args.empty?
            super(DSL.eval &Proc.new)
          else
            super
          end
        end

        def where(opts = Proc.new, *rest)
          if block_given? && Proc === opts
            super(DSL.eval &opts)
          else
            super
          end
        end

        def having(*args)
          if block_given? && args.empty?
            super(DSL.eval &Proc.new)
          else
            super
          end
        end

        def build_where(opts, other = [])
          case opts
          when String, Array
            super
          else  # Let's prevent PredicateBuilder from doing its thing
            [opts, *other].map do |arg|
              case arg
              when Array  # Just in case there's an array in there somewhere
                @klass.send(:sanitize_sql, arg)
              when Hash
                @klass.send(:expand_hash_conditions_for_aggregates, arg)
              else
                arg
              end
            end
          end
        end

        def collapse_wheres(arel, wheres)
          wheres = Array(wheres)
          binaries = wheres.grep(Arel::Nodes::Binary)

          groups = binaries.group_by {|b| [b.class, b.left]}

          groups.each do |_, bins|
            arel.where(Arel::Nodes::And.new(bins))
          end

          (wheres - binaries).each do |where|
            where = Arel.sql(where) if String === where
            arel.where(Arel::Nodes::Grouping.new(where))
          end
        end

        def find_equality_predicates(nodes)
          nodes.map { |node|
            case node
            when Arel::Nodes::Equality
              node if node.left.relation.name == table_name
            when Arel::Nodes::Grouping
              find_equality_predicates([node.expr])
            when Arel::Nodes::And
              find_equality_predicates(node.children)
            else
              nil
            end
          }.compact.flatten
        end

        # Simulate the logic that occurs in #to_a
        #
        # This will let us get a dump of the SQL that will be run against the
        # DB for debug purposes without actually running the query.
        def debug_sql
          if eager_loading?
            including = (@eager_load_values + @includes_values).uniq
            join_dependency = JoinDependency.new(@klass, including, [])
            construct_relation_for_association_find(join_dependency).to_sql
          else
            arel.to_sql
          end
        end

        ### ZOMG ALIAS_METHOD_CHAIN IS BELOW. HIDE YOUR EYES!
        # ...
        # ...
        # ...
        # Since you're still looking, let me explain this horrible
        # transgression you see before you.
        # You see, Relation#where_values_hash is defined on the
        # ActiveRecord::Relation class. Since it's defined there, but
        # I would very much like to modify its behavior, I have three
        # choices.
        #
        # 1. Inherit from ActiveRecord::Relation in a Squeel::Relation
        #    class, and make an attempt to usurp all of the various calls
        #    to methods on ActiveRecord::Relation by doing some really
        #    evil stuff with constant reassignment, all for the sake of
        #    being able to use super().
        #
        # 2. Submit a patch to Rails core, breaking this method off into
        #    another module, all for my own selfish desire to use super()
        #    while mucking about in Rails internals.
        #
        # 3. Use alias_method_chain, and say 10 hail Hanssons as penance.
        #
        # I opted to go with #3. Except for the hail Hansson thing.
        # Unless you're DHH, in which case, I totally said them.

        def self.included(base)
          base.class_eval do
            alias_method_chain :where_values_hash, :squeel
          end
        end

        def where_values_hash_with_squeel
          equalities = find_equality_predicates(predicate_visitor.accept(@where_values))

          Hash[equalities.map { |where| [where.left.name, where.right] }]
        end

      end
    end
  end
end