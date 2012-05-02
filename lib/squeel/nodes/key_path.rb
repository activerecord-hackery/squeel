require 'squeel/nodes/operators'
require 'squeel/nodes/predicate_operators'
require 'active_support/core_ext/module'

module Squeel
  module Nodes
    # A node that stores a path of keys (of Symbol, Stub, or Join values) and
    # an endpoint. Used similarly to a nested hash.
    class KeyPath
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

      # @return The endpoint, either another key as in the path, or a predicate, function, etc.
      attr_reader :endpoint

      # Create a new KeyPath.
      # @param [Array, Object] path The intial path. Will be converted to an array if it isn't already.
      # @param endpoint the endpoint of the KeyPath
      # @param [Boolean] absolute If the KeyPath should start from the base
      #   or remain relative to whatever location it's found.
      def initialize(path, endpoint, absolute = false)
        @path, @endpoint = path, endpoint
        @path = [@path] unless Array === @path
        @endpoint = Stub.new(@endpoint) if Symbol === @endpoint
        @absolute = absolute
      end

      # Whether or not the KeyPath should be interpreted relative to its current location
      #   (if nested in a Hash, for instance) or as though it's at the base.
      # @return [Boolean] The flag's value
      def absolute?
        @absolute
      end

      # Object comparison
      def eql?(other)
        self.class.eql?(other.class) &&
        self.path.eql?(other.path) &&
        self.endpoint.eql?(other.endpoint) &&
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
          @path << endpoint
          @endpoint = Sifter.new(name, args)
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
        [self.class, endpoint, *path].hash
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

      # @return [Array] The KeyPath's path, including its endpoint, as a single array.
      def path_with_endpoint
        path + [endpoint]
      end

      # Implement (and alias to :to_str) to play nicely with ActiveRecord grouped calculations
      def to_s
        path.map(&:to_s).join('.') << ".#{endpoint}"
      end
      alias :to_str :to_s

      # Appends to the KeyPath or delegates to the endpoint, as appropriate
      # @return [KeyPath] The updated KeyPath
      def method_missing(method_id, *args)
        super if method_id == :to_ary

        if endpoint.respond_to? method_id
          @endpoint = @endpoint.send(method_id, *args)
          self
        elsif Stub === endpoint || Join === endpoint
          @path << endpoint
          if args.empty?
            @endpoint = Stub.new(method_id)
          elsif (args.size == 1) && (Class === args[0])
            @endpoint = Join.new(method_id, Arel::InnerJoin, args[0])
          else
            @endpoint = Nodes::Function.new method_id, args
          end
          self
        else
          super
        end
      end

      private

      # Raises a NoMethodError manually, bypassing #method_missing.
      # Used by special-case operator overrides.
      def no_method_error(method_id)
        raise NoMethodError, "undefined method `#{method_id}' for #{self}:#{self.class}"
      end

    end
  end
end
