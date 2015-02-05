require 'squeel/adapters/active_record/relation_extensions'

module Squeel
  module Adapters
    module ActiveRecord
      module RelationExtensions

        attr_accessor :stashed_join_dependencies
        private :stashed_join_dependencies, :stashed_join_dependencies=

        def reset
          @stashed_join_dependencies = nil
          super
        end

        # where.not is a pain. It calls the private `build_where` method on its
        # scope, and since ActiveRecord::Relation already includes the original
        # ActiveRecord::QueryMethods module, we have to find a way to trick the
        # scope passed to the WhereChain initializer into having the original
        # behavior. This is a way to do it that avoids using alias_method_chain.
        module WhereChainCompatibility
          include ::ActiveRecord::QueryMethods
          define_method :build_where,
            ::ActiveRecord::QueryMethods.instance_method(:build_where)
        end

        def where(opts = :chain, *rest)
          if block_given?
            super(DSL.eval &Proc.new)
          else
            if opts == :chain
              scope = spawn
              scope.extend(WhereChainCompatibility)
              ::ActiveRecord::QueryMethods::WhereChain.new(scope)
            else
              super
            end
          end
        end

        def visited
          visit!
        end

        def where_unscoping(target_value)
          target_value = target_value.to_s

          where_values.reject! do |rel|
            case rel
            when Arel::Nodes::In, Arel::Nodes::NotIn, Arel::Nodes::Equality, Arel::Nodes::NotEqual
              subrelation = (rel.left.kind_of?(Arel::Attributes::Attribute) ? rel.left : rel.right)
              subrelation.name == target_value
            when Hash
              rel.stringify_keys.has_key?(target_value)
            when Squeel::Nodes::Predicate
              rel.expr.symbol.to_s == target_value if rel.expr.respond_to?(:symbol)
            end
          end

          bind_values.reject! { |col,_| col.name == target_value }
        end

        def reverse_sql_order(order_query)
          return super if order_query.empty?

          order_query.flat_map do |o|
            case o
              when Arel::Attributes::Attribute
                Arel::Nodes::Ascending.new(o).reverse
              else
                super
              end
          end
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

          # Reorder bind indexes when joins or subqueries include more bindings.
          # Special for PostgreSQL
          if arel.bind_values.any? || bind_values.size > 1
            bvs = arel.bind_values + bind_values
            arel.ast.grep(Arel::Nodes::BindParam).each_with_index do |bp, i|
              column = bvs[i].first
              bp.replace connection.substitute_at(column, i)
            end
          end

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
          subquery_joins            = (buckets[:subquery_join] || []).uniq
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

          joins = join_dependency.join_constraints stashed_association_joins

          joins.each { |join| manager.from(join) }

          manager.join_sources.concat(join_list)
          manager.join_sources.concat(build_join_from_subquery(subquery_joins))

          manager
        end

        alias :build_joins :build_join_dependency

        # Redefine all visiting methods that depends on build_join
        # All includes_values and eager_loading_values are pushed into a new
        # JoinDependency class after Rails 4.1 and never are grafted,
        # so that we need to walk through all JoinDependency
        # to find proper alias table names.
        #
        # And use a ! method in Context, so we can throw an error when we can't
        # find proper value in a JoinDependency
        %w(where having group order).each do |visitor|
          define_method "#{visitor}_visit" do |values|
            join_dependencies = [join_dependency] + stashed_join_dependencies
            join_dependencies.each do |jd|
              context = Adapters::ActiveRecord::Context.new(jd)
              begin
                return Visitors.const_get("#{visitor.capitalize}Visitor").new(context).accept!(values)
              rescue Adapters::ActiveRecord::Context::NoParentFoundError => e
                next
              end
            end

            # Fail Safe, call the normal accept method.
            context = Adapters::ActiveRecord::Context.new(join_dependency)
            Visitors.const_get("#{visitor.capitalize}Visitor").new(context).accept(values)
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
                super
              when Hash
                attributes = expand_attrs_from_hash(arg)

                preprocess_attrs_with_ar(attributes)
              when Squeel::Nodes::Node
                arg.grep(::ActiveRecord::Relation) do |rel|
                  self.bind_values += rel.bind_values
                end
                arg
              else
                arg
              end
            end
          end
        end

        def build_from
          opts, name = from_visit(from_value)
          case opts
          when ::ActiveRecord::Relation
            name ||= 'subquery'
            self.bind_values = opts.bind_values + self.bind_values
            opts.arel.as(name.to_s)
          when ::Arel::SelectManager
            name ||= 'subquery'
            opts.as(name.to_s)
          else
            opts
          end
        end

        def build_order(arel)
          orders = order_visit(dehashified_order_values)
          orders = orders.uniq.reject(&:blank?)
          orders = reverse_sql_order(orders) if reverse_order_value && !reordering_value

          arel.order(*orders) unless orders.empty?
        end

        def build_select(arel)
          if select_values.any?
            arel.project(*select_visit(select_values.uniq))
          else
            arel.project(@klass.arel_table[Arel.star])
          end
        end

        def where_values_hash_with_squeel(relation_table_name = table_name)
          equalities = find_equality_predicates(where_visit(where_values), relation_table_name)
          binds = Hash[bind_values.find_all(&:first).map { |column, v| [column.name, v] }]

          Hash[equalities.map { |where|
            name = where.left.name
            [name, binds.fetch(name.to_s) { where.right }]
          }]
        end

        def debug_sql
          eager_loading? ? to_sql : arel.to_sql
        end

        def to_sql_with_binding_params
          @to_sql ||= begin
            relation   = self
            connection = klass.connection

            if eager_loading?
              find_with_associations { |rel| relation = rel }
            end

            ast   = relation.arel.ast
            binds = relation.bind_values.dup

            visitor = connection.visitor.clone
            visitor.class_eval do
              include ::Arel::Visitors::BindVisitor
            end

            visitor.accept(ast) do
              connection.quote(*binds.shift.reverse)
            end
          end
        end

        private

          def expand_attrs_from_hash(opts)
            opts = ::ActiveRecord::PredicateBuilder.resolve_column_aliases(klass, opts)
            attributes = @klass.send(:expand_hash_conditions_for_aggregates, opts)

            attributes.values.grep(::ActiveRecord::Relation) do |rel|
              self.bind_values += rel.bind_values
            end

            attributes
          end

          def dehashified_order_values
            order_values.map { |o|
              if Hash === o && o.values.all? { |v| [:asc, :desc].include?(v) }
                o.map { |field, dir| table[field].send(dir) }
              else
                o
              end
            }
          end

          def build_join_from_subquery(subquery_joins)
            subquery_joins.map do |join|
              join.type.new(
                Arel::Nodes::TableAlias.new(join.subquery.left.arel, join.subquery.right),
                Arel::Nodes::On.new(where_visit(join.constraints))
              )
            end
          end
      end
    end
  end
end

ActiveRecord::Relation.send :include, Squeel::Adapters::ActiveRecord::RelationExtensions
