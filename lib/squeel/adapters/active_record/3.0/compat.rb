module Arel

  class SelectManager
    def as other
      Nodes::TableAlias.new Nodes::SqlLiteral.new(other), Nodes::Grouping.new(@ast)
    end
  end

  class Table
    alias :table_name :name

    def [] name
      if table_exists?
        columns.find { |column| column.name == name.to_sym }
      else
        ::Arel::Attribute.new self, name.to_sym
      end
    end

    def hash
      [name, engine].hash
    end

    def eql?(other)
      self.class == other.class &&
        self.name == other.name &&
        self.engine == other.engine
    end
    alias :== :eql?
  end

  module Attributes

    class Attribute < Attribute.superclass

      def hash
        [relation, name].hash
      end

      def eql?(other)
        self.class == other.class &&
          self.relation == other.relation &&
          self.name == other.name
      end
      alias :== :eql?

    end

  end

  module Nodes
    class Node
      def not
        Nodes::Not.new self
      end
    end

    remove_const :And
    class And < Arel::Nodes::Node
      attr_reader :children

      def initialize children, right = nil
        unless Array === children
          children = [children, right]
        end
        @children = children
      end

      def left
        children.first
      end

      def right
        children[1]
      end
    end

    class Function < Arel::Nodes::Node
      include Arel::Predications

      def as aliaz
        self.alias = SqlLiteral.new(aliaz)
        self
      end
    end

    class NamedFunction < Arel::Nodes::Function
      attr_accessor :name, :distinct

      def initialize name, expr, aliaz = nil
        super(expr, aliaz)
        @name = name
        @distinct = false
      end
    end

    class InfixOperation < Binary
      include Arel::Expressions
      include Arel::Predications

      attr_reader :operator

      def initialize operator, left, right
        super(left, right)
        @operator = operator
      end
    end

    class Multiplication < InfixOperation
      def initialize left, right
        super(:*, left, right)
      end
    end

    class Division < InfixOperation
      def initialize left, right
        super(:/, left, right)
      end
    end

    class Addition < InfixOperation
      def initialize left, right
        super(:+, left, right)
      end
    end

    class Subtraction < InfixOperation
      def initialize left, right
        super(:-, left, right)
      end
    end

    class Grouping < Unary
      include Arel::Predications
    end unless Grouping.include?(Arel::Predications)
  end

  module Visitors
    class ToSql
      def column_for attr
        name    = attr.name.to_s
        table   = attr.relation.table_name

        column_cache[table][name]
      end

      def column_cache
        @column_cache ||= Hash.new do |hash, key|
          hash[key] = Hash[
            @engine.connection.columns(key, "#{key} Columns").map do |c|
              [c.name, c]
            end
          ]
        end
      end

      def visit_Arel_Nodes_InfixOperation o
        "#{visit o.left} #{o.operator} #{visit o.right}"
      end

      def visit_Arel_Nodes_NamedFunction o
        "#{o.name}(#{o.distinct ? 'DISTINCT ' : ''}#{o.expressions.map { |x|
          visit x
        }.join(', ')})#{o.alias ? " AS #{visit o.alias}" : ''}"
      end

      def visit_Arel_Nodes_And o
        o.children.map { |x| visit x }.join ' AND '
      end

      def visit_Arel_Nodes_Not o
        "NOT (#{visit o.expr})"
      end

      def visit_Arel_Nodes_Values o
        "VALUES (#{o.expressions.zip(o.columns).map { |value, attr|
          if Nodes::SqlLiteral === value
            visit_Arel_Nodes_SqlLiteral value
          else
            quote(value, attr && column_for(attr))
          end
        }.join ', '})"
      end

      def quote_table_name name
        return name if Arel::Nodes::SqlLiteral === name
        @quoted_tables[name] ||= @connection.quote_table_name(name)
      end
    end
  end

  module Predications
    def as other
      Nodes::As.new self, Nodes::SqlLiteral.new(other)
    end
  end

end

module ActiveRecord
  module Reflection
    class AssociationReflection < MacroReflection
      alias :foreign_key :primary_key_name
      def foreign_type
        options[:foreign_type]
      end
    end
  end
end
