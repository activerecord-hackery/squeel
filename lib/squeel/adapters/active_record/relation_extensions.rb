require 'active_record'

module Squeel
  module Adapters
    module ActiveRecord
      module RelationExtensions

        attr_writer :join_dependency
        private :join_dependency=

        # Returns a JoinDependency for the current relation.
        #
        # We don't need to clear out @join_dependency by overriding #reset,
        # because the default #reset already does this, despite never setting
        # it anywhere that I can find. Serendipity, I say!
        def join_dependency
          @join_dependency ||= (
            build_join_dependency(
              Arel::SelectManager.new(table.engine, table),
              joins_values
            ) && @join_dependency
          )
        end

        %w(where having group order select from).each do |visitor|
          define_method "#{visitor}_visit" do |values|
            Visitors.const_get("#{visitor.capitalize}Visitor").new(
              Context.new(join_dependency)
            ).accept(values)
          end
        end

        # We need to be able to support merging two relations without having
        # to get our hooks too deeply into Active Record. That proves to be
        # easier said than done. I hate Relation#merge. If Squeel has a
        # nemesis, Relation#merge would be it.
        #
        # Whatever code you see here currently is my current best attempt at
        # coexisting peacefully with said nemesis.
        def merge(r, equalities_resolved = false)
          if ::ActiveRecord::Relation === r && !equalities_resolved
            if self.table_name != r.table_name
              super(r.visited)
            else
              merge_resolving_duplicate_squeel_equalities(r)
            end
          else
            super(r)
          end
        end

        def visited
          with_default_scope.visit!
        end

        def visit!
          self.where_values = where_visit((where_values - ['']).uniq)
          self.having_values = having_visit(having_values.uniq.reject{|h| h.blank?})
          # FIXME: AR barfs on Arel attributes in group_values. Workaround?
          # self.group_values = group_visit(group_values.uniq.reject{|g| g.blank?})
          self.order_values = order_visit(order_values.uniq.reject{|o| o.blank?})
          self.select_values = select_visit(select_values.uniq)

          self
        end

        # reverse_sql_order will reverse the order of strings or Orderings,
        # but not attributes
        def attrs_to_orderings(order)
          order.map do |o|
            Arel::Attribute === o ? o.asc : o
          end
        end

        # So, building a select for a count query in Active Record is
        # pretty heavily dependent on select_values containing strings.
        # I'd initially expected that I could just hack together a fix
        # to select_for_count and everything would fall in line, but
        # unfortunately, pretty much everything from that point on
        # in ActiveRecord::Calculations#perform_calculation expects
        # the column to be a string, or at worst, a symbol.
        #
        # In the long term, I would like to refactor the code in
        # Rails core, but for now, I'm going to settle for this hack
        # that tries really hard to coerce things to a string.
        def select_for_count
          visited_values = select_visit(select_values.uniq)
          if visited_values.size == 1
            select = visited_values.first

            str_select = case select
            when String
              select
            when Symbol
              select.to_s
            else
              select.to_sql if select.respond_to?(:to_sql)
            end

            str_select if str_select && str_select !~ /[,*]/
          else
            :all
          end
        end

        def build_join_dependency(manager, joins)
          buckets = joins.group_by do |join|
            case join
            when String
              :string_join
            when Hash, Symbol, Array, Nodes::Stub, Nodes::Join, Nodes::KeyPath
              :association_join
            when JoinAssociation
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
          subquery_joins            = (buckets[:subquery_join] || []).uniq
          string_joins              = (buckets[:string_join] || []).map { |x|
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

          manager.join_sources.concat(join_list)
          manager.join_sources.concat(build_join_from_subquery(subquery_joins))

          manager
        end
        # For 4.0 adapters
        alias :build_joins :build_join_dependency

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
            if value.arity > 0 || (Squeel.sane_arity? && value.arity < 0)
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

        def from(*args)
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

          arel.where(Arel::Nodes::And.new(groups.map{|_, bins| bins}.flatten)) if groups.any?

          (wheres - binaries).each do |where|
            where = Arel.sql(where) if String === where
            arel.where(Arel::Nodes::Grouping.new(where))
          end
        end

        def find_equality_predicates(nodes, relation_table_name = table_name)
          nodes.map { |node|
            case node
            when Arel::Nodes::Equality
              if node.left.respond_to?(:relation) &&
                node.left.relation.name == relation_table_name
                node
              end
            when Arel::Nodes::Grouping
              find_equality_predicates([node.expr])
            when Arel::Nodes::And
              find_equality_predicates(node.children)
            else
              nil
            end
          }.compact.flatten
        end

        def flatten_nodes(nodes)
          nodes.map { |node|
            case node
            when Array
              flatten_nodes(node)
            when Nodes::And
              flatten_nodes(node.children)
            when Nodes::Grouping
              flatten_nodes(node.expr)
            else
              node
            end
          }.flatten
        end

        def merge_resolving_duplicate_squeel_equalities(r)
          left = clone
          right = r.clone
          left.where_values = flatten_nodes(left.where_values)
          right.where_values = flatten_nodes(right.where_values)
          right_equalities = right.where_values.select do |obj|
            Nodes::Predicate === obj && obj.method_name == :eq
          end
          right.where_values -= right_equalities
          left.where_values = resolve_duplicate_squeel_equalities(
            left.where_values + right_equalities
          )
          left.merge(right, true)
        end

        def resolve_duplicate_squeel_equalities(wheres)
          seen = {}
          wheres.reverse.reject { |n|
            nuke = false
            if Nodes::Predicate === n && n.method_name == :eq
              nuke       = seen[n.expr]
              seen[n.expr] = true
            end
            nuke
          }.reverse
        end

        # Simulate the logic that occurs in #to_a
        #
        # This will let us get a dump of the SQL that will be run against the
        # DB for debug purposes without actually running the query.
        def debug_sql
          if eager_loading?
            including = (eager_load_values + includes_values).uniq
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
        #
        # You see, Relation#where_values_hash is defined on the
        # ActiveRecord::Relation class, itself.
        #
        # Since it's defined there, but I would very much like to modify its
        # behavior, I have three choices:
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
        #
        # If you'd like to read more about alias_method_chain, see
        # http://erniemiller.org/2011/02/03/when-to-use-alias_method_chain/

        def self.included(base)
          base.class_eval do
            alias_method_chain :where_values_hash, :squeel
          end
        end

        # where_values_hash is used in scope_for_create. It's what allows
        # new records to be created with any equality values that exist in
        # your model's default scope. We hijack it in order to dig down into
        # And and Grouping nodes, which are equivalent to seeing top-level
        # Equality nodes in stock AR terms.
        def where_values_hash_with_squeel(relation_table_name = table_name)
          equalities = find_equality_predicates(where_visit(with_default_scope.where_values), relation_table_name)
          binds = Hash[bind_values.find_all(&:first).map { |column, v| [column.name, v] }]

          Hash[equalities.map { |where|
            name = where.left.name
            [name, binds.fetch(name.to_s) { where.right }]
          }]
        end

        def build_join_from_subquery(subquery_joins)
          subquery_joins.map do |join|
            join.type.new(
              Arel::Nodes::TableAlias.new(
                Arel::Nodes::Grouping.new(join.subquery.left.arel.ast),
                join.subquery.right),
              Arel::Nodes::On.new(where_visit(join.constraints))
            )
          end
        end

        def preprocess_attrs_with_ar(attributes)
          attributes.map do |key, value|
            case key
              when Squeel::Nodes::Node
                {key => value}
              when Symbol
                if value.is_a?(Hash)
                  {key => value}
                else
                  ::ActiveRecord::PredicateBuilder.build_from_hash(klass, {key => value}, table)
                end
              else
                ::ActiveRecord::PredicateBuilder.build_from_hash(klass, {key => value}, table)
              end
          end
        end

        def execute_grouped_calculation(operation, column_name, distinct)
          arel = Arel::SelectManager.new(table.engine, table)
          build_join_dependency(arel, joins_values.flatten) unless joins_values.empty?
          self.group_values = group_visit(group_values.uniq.reject{|g| g.blank?}) unless group_values.empty?
          super
        end
      end
    end
  end
end
