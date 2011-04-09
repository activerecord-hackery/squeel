require 'squeel/nodes/operators'
require 'squeel/nodes/predicate_operators'

module Squeel
  module Nodes
    class KeyPath
      include PredicateOperators
      include Operators

      attr_reader :path, :endpoint

      def initialize(path, endpoint, absolute = false)
        @path, @endpoint = path, endpoint
        @path = [@path] unless Array === @path
        @endpoint = Stub.new(@endpoint) if Symbol === @endpoint
        @absolute = absolute
      end

      def absolute?
        @absolute
      end

      def eql?(other)
        self.class == other.class &&
        self.path == other.path &&
        self.endpoint.eql?(other.endpoint) &&
        self.absolute? == other.absolute?
      end

      def |(other)
        endpoint.respond_to?(:|) ? super : no_method_error(:|)
      end

      def &(other)
        endpoint.respond_to?(:&) ? super : no_method_error(:&)
      end

      def -@
        endpoint.respond_to?(:-@) ? super : no_method_error(:-@)
      end

      def +(other)
        endpoint.respond_to?(:+) ? super : no_method_error(:+)
      end

      def -(other)
        endpoint.respond_to?(:-) ? super : no_method_error(:-)
      end

      def *(other)
        endpoint.respond_to?(:*) ? super : no_method_error(:*)
      end

      def /(other)
        endpoint.respond_to?(:/) ? super : no_method_error(:/)
      end

      def op(operator, other)
        endpoint.respond_to?(:op) ? super : no_method_error(:/)
      end

      def ~
        @absolute = true
        self
      end

      # To let these fall through to the endpoint via method_missing
      instance_methods.grep(/^(==|=~|!~)$/) do |operator|
        undef_method operator
      end

      def hash
        [self.class, endpoint, *path].hash
      end

      def to_sym
        nil
      end

      def %(val)
        case endpoint
        when Stub, Function
          eq(val)
          self
        else
          endpoint % val
          self
        end
      end

      def path_with_endpoint
        path + [endpoint]
      end

      def to_s
        path.map(&:to_s).join('.') << ".#{endpoint}"
      end

      def method_missing(method_id, *args)
        super if method_id == :to_ary
        if endpoint.respond_to? method_id
          @endpoint = @endpoint.send(method_id, *args)
          self
        elsif Stub === endpoint
          @path << endpoint.symbol
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

      def no_method_error(method_id)
        raise NoMethodError, "undefined method `#{method_id}' for #{self}:#{self.class}"
      end

    end
  end
end