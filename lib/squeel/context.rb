require 'arel'

module Squeel
  # @abstract Subclass and implement {#traverse}, {#find} and {#get_table}
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
    #
    # @param object The object the context will use for contextualization
    def initialize(object)
      @object = object
      @tables = Hash.new {|hash, key| hash[key] = get_table(key)}
    end

    # This method should find a given object inside the context.
    #
    # @param object The object to find
    # @param parent The parent object, if applicable
    # @return a valid "parent" or contextualizable object
    def find(object, parent = @base)
      raise NotImplementedError, "Subclasses must implement public method find"
    end

    # This method should traverse a keypath and return an object for use
    # in future calls to #traverse, #find, or #contextualize.
    #
    # @param [Nodes::KeyPath] keypath The keypath to traverse
    # @param parent The parent object from which traversal should start.
    # @param [Boolean] include_endpoint Whether or not the KeyPath's
    #   endpoint should be treated as a traversable key
    # @return a valid "parent" or contextualizable object
    def traverse(keypath, parent = @base, include_endpoint = false)
      raise NotImplementedError, "Subclasses must implement public method traverse"
    end

    # This method, as implemented, just makes use of the table cache, which will
    # call get_table, where the real work of getting the Arel Table occurs.
    #
    # @param object A contextualizable object (this will depend on the subclass's implementation)
    # @return [Arel::Table] A table corresponding to the object param
    def contextualize(object)
      @tables[object]
    end

    private

    # Returns an Arel::Table that's appropriate for the object it's been sent.
    # What's "appropriate"? Well, that's up to the implementation to decide, but
    # it should probably generate a table that is least likely to result in invalid
    # SQL.
    #
    # @param object A contextualizable object (this will depend on the subclass's implementation)
    # @return [Arel::Table] A table corresponding to the object param.
    def get_table(object)
      raise NotImplementedError, "Subclasses must implement private method get_table"
    end

    # Returns a class for the corresponding object.
    #
    # @param object A classifiable object (this will depend on the subclass's implementation)
    # @return [Class] The class corresponding to the object
    def classify(object)
      raise NotImplementedError, "Subclasses must implement private method classify"
    end

  end
end
