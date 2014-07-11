require 'active_support/core_ext/module'

module Squeel
  module Nodes
    # A node that stores a path of keys (of Symbol, Stub, or Join values) and
    # an endpoint. Used similarly to a nested hash.
    class KeyPath < Node
      include PredicateOperators
      include Operators

      # We need some methods to fall through to the endpoint or create a new
      # stub of the given name
      %w(id type == != =~ !~ desc).each do |method_name|
        undef_method method_name if method_defined?(method_name) ||
          private_method_defined?(method_name)
      end

      # @return [Array<Symbol, Stub, Join>] The path
      attr_reader :path

      # Create a new KeyPath.
      # @param [Array, Object] path The intial path. Will be converted to an array if it isn't already.
      # @param [Boolean] absolute If the KeyPath should start from the base
      #   or remain relative to whatever location it's found.
      def initialize(path, absolute = false)
        @path = Array(path)
        self.endpoint = Stub.new(endpoint) if Symbol === endpoint
        @absolute = absolute
      end

      # Whether or not the KeyPath should be interpreted relative to its current location
      #   (if nested in a Hash, for instance) or as though it's at the base.
      # @return [Boolean] The flag's value
      def absolute?
        @absolute
      end

      # @return The endpoint, either another key as in the path, or a predicate, function, etc.
      def endpoint
        @path[-1]
      end

      # Set the new value of the KeyPath's endpoint.
      # @param [Object] val The new endpoint.
      # @return The value just set.
      def endpoint=(val)
        @path[-1] = val
      end

      # Object comparison
      def eql?(other)
        self.class.eql?(other.class) &&
        self.path.eql?(other.path) &&
        self.absolute?.eql?(other.absolute?)
      end

      # Allow KeyPath to function like its endpoint, in the case where its endpoint
      # responds to |
      # @param other The right hand side of the operation
      # @return [Or] An Or node with the KeyPath on the left side and the other object on the right.
      def |(other)
        endpoint.respond_to?(:|) ? super : no_method_error(:|)
      end

      # Allow KeyPath to function like its endpoint, in the case where its endpoint
      # responds to &
      # @param other The right hand side of the operation
      # @return [And] An And node with the KeyPath on the left side and the other object on the right.
      def &(other)
        endpoint.respond_to?(:&) ? super : no_method_error(:&)
      end

      # Allow KeyPath to function like its endpoint, in the case where its endpoint
      # responds to -@
      # @return [Not] A not node with the KeyPath as its expression
      def -@
        endpoint.respond_to?(:-@) ? super : no_method_error(:-@)
      end

      # Allow KeyPath to function like its endpoint, in the case where its endpoint
      # responds to +
      # @param other The right hand side of the operation
      # @return [Operation] An operation (with operator +) with the KeyPath on its left and the other object on the right.
      def +(other)
        endpoint.respond_to?(:+) ? super : no_method_error(:+)
      end

      # Allow KeyPath to function like its endpoint, in the case where its endpoint
      # responds to -
      # @param other The right hand side of the operation
      # @return [Operation] An operation (with operator -) with the KeyPath on its left and the other object on the right.
      def -(other)
        endpoint.respond_to?(:-) ? super : no_method_error(:-)
      end

      # Allow KeyPath to function like its endpoint, in the case where its endpoint
      # responds to *
      # @param other The right hand side of the operation
      # @return [Operation] An operation (with operator *) with the KeyPath on its left and the other object on the right.
      def *(other)
        endpoint.respond_to?(:*) ? super : no_method_error(:*)
      end

      # Allow KeyPath to function like its endpoint, in the case where its endpoint
      # responds to /
      # @param other The right hand side of the operation
      # @return [Operation] An operation (with operator /) with the KeyPath on its left and the other object on the right.
      def /(other)
        endpoint.respond_to?(:/) ? super : no_method_error(:/)
      end

      # Allow KeyPath to function like its endpoint, in the case where its endpoint
      # responds to #op
      # @param [String, Symbol] operator The custom operator
      # @param other The right hand side of the operation
      # @return [Operation] An operation with the given custom operator, the KeyPath on its left and the other object on the right.
      def op(operator, other)
        endpoint.respond_to?(:op) ? super : no_method_error(:op)
      end

      # Allow KeyPath to have a sifter as its endpoint, if the endpoint is a
      # chainable node (Stub or Join)
      # @param [Symbol] name The name of the sifter
      # @return [KeyPath] This keypath, with a sifter as its endpoint
      def sift(name, *args)
        if Stub === endpoint || Join === endpoint
          @path << Sifter.new(name, args)
          self
        else
          no_method_error :sift
        end
      end

      # Set the absolute flag on this KeyPath
      # @return [KeyPath] This keypath, with its absolute flag set to true
      def ~
        @absolute = true
        self
      end

      # For use with equality tests
      def hash
        [self.class, *path].hash
      end

      # expand_hash_conditions_for_aggregates assumes our hash keys can be
      # converted to symbols, so this has to be implemented, but it doesn't
      # really have to do anything useful.
      # @return [NilClass] Just to avoid bombing out on expand_hash_conditions_for_aggregates
      def to_sym
        nil
      end

      # Delegate % to the KeyPath's endpoint, with a bit of special logic for stubs or functions.
      # @param val The value to be supplied to the created/existing predicate
      # @return [KeyPath] This KeyPath, with a predicate endpoint containing the given value
      def %(val)
        case endpoint
        when Stub, Function
          Array === val ? self.in(val) : self.eq(val)
          self
        else
          endpoint % val
          self
        end
      end

      # @return [Array] The KeyPath's path, minus its endpoint, as a single array.
      def path_without_endpoint
        path[0..-2]
      end

      # Implement #to_s (and alias to #to_str) to play nicely with Active Record
      # grouped calculations
      def to_s
        path.map(&:to_s).join('.')
      end
      alias :to_str :to_s

      def add_to_tree(hash)
        walk_through_path(path.dup, hash)
      end

      # Appends to the KeyPath or delegates to the endpoint, as appropriate
      # @return [KeyPath] The updated KeyPath
      def method_missing(method_id, *args, &block)
        super if method_id == :to_ary

        if endpoint.respond_to?(method_id)
          if Predicate === endpoint && method_id == :==
            false
          else
            # TODO: We really should not mutate here.
            self.endpoint = endpoint.send(method_id, *args)
            self
          end
        elsif Stub === endpoint || Join === endpoint
          if args.empty?
            @path << Stub.new(method_id)
          elsif (args.size == 1) && (Class === args[0])
            @path << Join.new(method_id, InnerJoin, args[0])
          else
            @path << Nodes::Function.new(method_id, args)
          end
          self
        else
          super
        end
      end

      private

      # Prevent a cloned keypath from inadvertently modifying the
      # path of its source.
      def initialize_copy(orig)
        super
        @path = @path.dup
      end

      def walk_through_path(path, hash)
        cache = path.shift.add_to_tree(hash)
        path.empty? ? cache : walk_through_path(path, cache)
      end

      # Raises a NoMethodError manually, bypassing #method_missing.
      # Used by special-case operator overrides.
      def no_method_error(method_id)
        raise NoMethodError, "undefined method `#{method_id}' for #{self}:#{self.class}"
      end

    end
  end
end
