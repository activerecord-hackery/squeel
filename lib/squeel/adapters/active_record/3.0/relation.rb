require 'active_record'

module Squeel
  module Adapters
    module ActiveRecord
      module Relation

        JoinAssociation = ::ActiveRecord::Associations::ClassMethods::JoinDependency::JoinAssociation
        JoinDependency = ::ActiveRecord::Associations::ClassMethods::JoinDependency

        attr_writer :join_dependency
        private :join_dependency=

        # Returns a JoinDependency for the current relation.
        #
        # We don't need to clear out @join_dependency by overriding #reset, because
        # the default #reset already does this, despite never setting it anywhere that
        # I can find. Serendipity, I say!
        def join_dependency
          @join_dependency ||= (build_join_dependency(table, @joins_values) && @join_dependency)
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
        # winding up against the proper table. Merging relations is a really nifty shortcut
        # but another little corner of ActiveRecord where the magic quickly fades. :(
        def merge(r, association_name = nil)
          if association_name || relation_with_different_base?(r)
            r = r.clone
            association_name ||= infer_association_for_relation_merge(r)
            prepare_relation_for_association_merge!(r, association_name)
            self.joins_values += [association_name] if reflect_on_association(association_name)
          end

          super(r)
        end

        def relation_with_different_base?(r)
          ::ActiveRecord::Relation === r &&
          base_class.name != r.klass.base_class.name
        end

        def infer_association_for_relation_merge(r)
          default_association = reflect_on_all_associations.detect {|a| a.class_name == r.klass.name}
          default_association ? default_association.name : r.table_name.to_sym
        end

        def prepare_relation_for_association_merge!(r, association_name)
          r.where_values.map! {|w| Squeel::Visitors::PredicateVisitor.can_visit?(w) ? {association_name => w} : w}
          r.having_values.map! {|h| Squeel::Visitors::PredicateVisitor.can_visit?(h) ? {association_name => h} : h}
          r.joins_values.map! {|j| [Symbol, Hash, Nodes::Stub, Nodes::Join].include?(j.class) ? {association_name => j} : j}
        end

        def build_arel
          arel = table

          arel = build_join_dependency(arel, @joins_values) unless @joins_values.empty?

          predicate_viz = predicate_visitor
          attribute_viz = attribute_visitor

          arel = collapse_wheres(arel, predicate_viz.accept((@where_values - ['']).uniq))

          arel = arel.having(*predicate_viz.accept(@having_values.uniq.reject{|h| h.blank?})) unless @having_values.empty?

          arel = arel.take(connection.sanitize_limit(@limit_value)) if @limit_value
          arel = arel.skip(@offset_value) if @offset_value

          arel = arel.group(*attribute_viz.accept(@group_values.uniq.reject{|g| g.blank?})) unless @group_values.empty?

          arel = arel.order(*attribute_viz.accept(@order_values.uniq.reject{|o| o.blank?})) unless @order_values.empty?

          arel = build_select(arel, attribute_viz.accept(@select_values.uniq))

          arel = arel.from(@from_value) if @from_value
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

          non_association_joins = (joins - association_joins - stashed_association_joins)
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

          relation = relation.join(custom_joins)
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
          wheres = [wheres] unless Array === wheres
          binaries = wheres.grep(Arel::Nodes::Binary)

          groups = binaries.group_by {|b| [b.class, b.left]}

          groups.each do |_, bins|
            arel = arel.where(bins.inject(&:and))
          end

          (wheres - binaries).each do |where|
            where = Arel.sql(where) if String === where
            arel = arel.where(Arel::Nodes::Grouping.new(where))
          end

          arel
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
            join_dependency = JoinDependency.new(@klass, including, nil)
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