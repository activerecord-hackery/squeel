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
          if visited_values.any?
            string_values = visited_values.map { |value|
              case value
              when String
                value
              when Symbol
                value.to_s
              when Arel::Attributes::Attribute
                join_name = value.relation.table_alias || value.relation.name
                "#{connection.quote_table_name join_name}.#{connection.quote_column_name value.name}"
              else
                value.respond_to?(:to_sql) ? value.to_sql : value
              end
            }
            string_values.join(', ')
          else
            :all
          end
        end

      end
    end
  end
end

ActiveRecord::Relation.send :include, Squeel::Adapters::ActiveRecord::RelationExtensions
