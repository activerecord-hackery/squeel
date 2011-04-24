require 'arel'

module Squeel
  # @abstract Subclass and implement {#traverse}, {#sanitize_sql}, and {#get_table}
  #   to create a Context that supports a given ORM.
  class Context
    attr_reader :base, :engine, :arel_visitor

    # The Squeel context expects some kind of context object that is
    # representative of the current joins in a query in order to return
    # appropriate tables. Again, in the case of an ActiveRecord context,
    # this will be a JoinDependency. Subclasses are expected to set the
    # <tt>@base</tt>, <tt>@engine</tt>, and <tt>@arel_visitor</tt>
    # instance variables to appropriate values for use in their implementations
    # of other required methods.
    def initialize(object)
      @object = object
      @tables = Hash.new {|hash, key| hash[key] = get_table(key)}
    end

    # This method should traverse a keypath and return an object for use
    # in future calls to traverse of contextualize.
    def traverse(keypath, parent = @base, include_endpoint = false)
      raise NotImplementedError, "Subclasses must implement public method traverse"
    end

    # This method, as implemented, just makes use of the table cache, which will
    # call get_table, where the real work of getting the ARel Table occurs.
    def contextualize(object)
      @tables[object]
    end

    # Should provides simple SQL sanitization/interpolation against a parent object.
    def sanitize_sql(conditions, parent)
      raise NotImplementedError, "Subclasses must implement public method sanitize_sql"
    end

    private

    # Returns an Arel::Table that's appropriate for the object it's been sent.
    # What's "appropriate"? Well, that's up to the implementation to decide, but
    # it should probably generate a table that is least likely to result in invalid
    # SQL. :)
    def get_table(object)
      raise NotImplementedError, "Subclasses must implement private method get_table"
    end

  end
end