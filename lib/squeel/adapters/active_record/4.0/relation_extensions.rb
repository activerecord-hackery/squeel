require 'squeel/adapters/active_record/relation_extensions'

module Squeel
  module Adapters
    module ActiveRecord
      module RelationExtensions

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
          arel.from(build_from) if from_value
          arel.lock(lock_value) if lock_value

          arel
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
                attrs = @klass.send(:expand_hash_conditions_for_aggregates, arg)
                attrs.values.grep(::ActiveRecord::Relation) do |rel|
                  self.bind_values += rel.bind_values
                end
                attrs
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

        # This is copied directly from 4.0.0's implementation, but adds an extra
        # exclusion for Squeel::Nodes::Node to fix #248. Can be removed if/when
        # rails/rails#11439 is merged.
        def order!(*args)
          args.flatten!
          validate_order_args args

          references = args.reject { |arg|
            Arel::Node === arg || Squeel::Nodes::Node === arg
          }
          references.map! { |arg| arg =~ /^([a-zA-Z]\w*)\.(\w+)/ && $1 }.compact!
          references!(references) if references.any?

          # if a symbol is given we prepend the quoted table name
          args = args.map { |arg|
            arg.is_a?(Symbol) ? "#{quoted_table_name}.#{arg} ASC" : arg
          }

          self.order_values = args + self.order_values
          self
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
