module Squeel
  class DSL

    Squeel.evil_things do
      (instance_methods + private_instance_methods).each do |method|
        unless method.to_s =~ /^(__|instance_eval)/
          undef_method method
        end
      end
    end

    def self.evaluate(&block)
      if block.arity > 0
        yield self.new
      else
        self.new.instance_eval(&block)
      end
    end

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