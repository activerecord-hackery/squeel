module Squeel
  # Interprets DSL blocks, generating various Squeel nodes as appropriate.
  class DSL

    # We're creating a BlankSlate-type class here, since we want most
    # method calls to fall through to method_missing.
    Squeel.evil_things do
      (instance_methods + private_instance_methods).each do |method|
        unless method.to_s =~ /^(__|instance_eval|instance_exec)/
          undef_method method
        end
      end
    end

    # Called from an adapter, not directly.
    # Evaluates a block of Squeel DSL code.
    #
    # @example A DSL block that uses instance_eval
    #   Post.where{title == 'Hello world!'}
    #
    # @example A DSL block with access to methods from the closure
    #   Post.where{|dsl| dsl.title == local_method(local_var)}
    #
    # @yield [dsl] A block of Squeel DSL code, with an optional argument if
    #   access to closure methods is desired.
    # @return The results of the interpreted DSL code.
    def self.eval(&block)
      if block.arity > 0
        yield self.new(block.binding)
      else
        self.new(block.binding).instance_eval(&block)
      end
    end

    # Called from an adapter, not directly.
    # Executes a block of Squeel DSL code, possibly with arguments.
    #
    # @return The results of the executed DSL code.
    def self.exec(*args, &block)
      self.new(block.binding).instance_exec(*args, &block)
    end

    private

    # This isn't normally called directly, but via DSL.eval, which will
    # pass the block's binding to the new instance, for use with #my.
    #
    # @param [Binding] The block's binding.
    def initialize(caller_binding)
      @caller = caller_binding.eval 'self'
    end

    # If you really need to get at an instance variable or method inside
    # a DSL block, this method will let you do it. It passes a block back
    # to the DSL's caller for instance_eval.
    #
    # It's also pretty evil, so I hope you enjoy using it while I'm burning in
    # programmer hell.
    #
    # @param &block A block to instance_eval against the DSL's caller.
    # @return The results of evaluating the block in the instance of the DSL's caller.
    def my(&block)
      @caller.instance_eval &block
    end

    # Shorthand for creating Arel SqlLiteral nodes.
    #
    # @param [String] string The string to convert to an SQL literal.
    # @return [Arel::Nodes::SqlLiteral] The SQL literal.
    def `(string)
      Nodes::Literal.new(string)
    end

    # Create a Squeel Grouping node. This allows you to set balanced
    # pairs of parentheses around your SQL.
    #
    # @param expr The expression to group
    # @return [Nodes::Grouping] The grouping node
    def _(expr)
      Nodes::Grouping.new(expr)
    end

    # Create a Squeel Sifter node. This essentially substitutes the
    # sifter block of the supplied name from the model.
    #
    # @param [Symbol, Nodes::Stub] name The name of the sifter defined in the model.
    # @return [Nodes::Sifter] The sifter node
    def sift(name, *args)
      Nodes::Sifter.new name.to_sym, args
    end

    # Node generation inside DSL blocks.
    #
    # @overload node_name
    #   Creates a Stub. Method calls chained from this Stub will determine
    #   what type of node we eventually end up with.
    #   @return [Nodes::Stub] A stub with the name of the method
    # @overload node_name(klass)
    #   Creates a Join with a polymorphic class matching the given parameter
    #   @param [Class] klass The polymorphic class of the join node
    #   @return [Nodes::Join] A join node with the name of the method and the given class
    # @overload node_name(first_arg, *other_args)
    #   Creates a Function with the given arguments becoming the function's arguments
    #   @param first_arg The first argument
    #   @param *other_args Optional additional arguments
    #   @return [Nodes::Function] A function node for the given method name with the given arguments
    def method_missing(method_id, *args)
      super if method_id == :to_ary

      if args.empty?
        Nodes::Stub.new method_id
      elsif (args.size == 1) && (Class === args[0])
        Nodes::Join.new(method_id, InnerJoin, args[0])
      else
        Nodes::Function.new method_id, args
      end
    end

  end
end
