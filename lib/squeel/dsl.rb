module Squeel
  class DSL

    # We're creating a BlankSlate-type class here, since we want most
    # method calls to fall through to method_missing.
    Squeel.evil_things do
      (instance_methods + private_instance_methods).each do |method|
        unless method.to_s =~ /^(__|instance_eval)/
          undef_method method
        end
      end
    end

    # Evaluate a block. If the block accepts a parameter, yield the DSL
    # object instead of doing an instance_eval. Useful if you need access
    # to methods in the calling scope that would otherwise be unavailable,
    # but it makes for more verbose code in the block, such as:
    #
    #   Post.where{|dsl| dsl.title == local_method(local_var)}
    def self.eval(&block)
      if block.arity > 0
        yield self.new
      else
        self.new.instance_eval(&block)
      end
    end

    # If no args are given, we'll just return a Stub of an appropriate name.
    # If a Class arg is given, we'll assume it's a polymorphic belongs_to join.
    # If other args are given, it's an SQL function call.
    def method_missing(method_id, *args)
      if args.empty?
        Nodes::Stub.new method_id
      elsif (args.size == 1) && (Class === args[0])
        Nodes::Join.new(method_id, Arel::InnerJoin, args[0])
      else
        Nodes::Function.new method_id, args
      end
    end

  end
end