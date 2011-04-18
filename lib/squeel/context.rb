require 'arel'

module Squeel
  class Context
    attr_reader :base, :engine, :arel_visitor

    def initialize(object)
      @object = object
      @engine = @base.arel_engine
      @arel_visitor = Arel::Visitors.visitor_for @engine
      @default_table = Arel::Table.new(@base.table_name, :as => @base.aliased_table_name, :engine => @engine)
      @tables = Hash.new {|hash, key| hash[key] = get_table(key)}
    end

    def find(object, parent = @base)
      raise NotImplementedError, "Subclasses must implement public method find"
    end

    def traverse(keypath, parent = @base, include_endpoint = false)
      raise NotImplementedError, "Subclasses must implement public method traverse"
    end

    def contextualize(object)
      @tables[object]
    end

    def sanitize_sql(conditions, parent)
      raise NotImplementedError, "Subclasses must implement public method sanitize_sql"
    end

    private

    def get_table(object)
      raise NotImplementedError, "Subclasses must implement private method get_table"
    end

  end
end