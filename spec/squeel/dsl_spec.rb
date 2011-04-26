require 'spec_helper'

module Squeel
  describe DSL do

    it 'evaluates code' do
      result = DSL.eval { {id => 1} }
      result.should be_a Hash
      result.keys.first.should be_a Nodes::Stub
    end

    it 'creates function nodes when a method has arguments' do
      result = DSL.eval { max(id) }
      result.should be_a Nodes::Function
      result.args.should eq [Nodes::Stub.new(:id)]
    end

    it 'creates polymorphic join nodes when a method has a single class argument' do
      result = DSL.eval { association(Person) }
      result.should be_a Nodes::Join
      result._klass.should eq Person
    end

    it 'handles OR between predicates' do
      result = DSL.eval {(name =~ 'Joe%') | (articles.title =~ 'Hello%')}
      result.should be_a Nodes::Or
      result.left.should be_a Nodes::Predicate
      result.right.should be_a Nodes::KeyPath
      result.right.endpoint.should be_a Nodes::Predicate
    end

    it 'is not a full closure (instance_evals) when the block supplied has no arity' do
      my_class = Class.new do
        def a_method
          'test'
        end

        def dsl_test
          DSL.eval {name =~ a_method}
        end
      end

      obj = my_class.new
      result = obj.dsl_test
      result.should be_a Nodes::Predicate
      result.expr.should eq :name
      result.method_name.should eq :matches
      result.value.should be_a Nodes::Stub
      result.value.symbol.should eq :a_method
    end

    it 'is a full closure (yields self) when the block supplied has an arity' do
      my_class = Class.new do
        def a_method
          'test'
        end

        def dsl_test
          DSL.eval {|q| q.name =~ a_method}
        end
      end

      obj = my_class.new
      result = obj.dsl_test
      result.should be_a Nodes::Predicate
      result.expr.should eq :name
      result.method_name.should eq :matches
      result.value.should be_a String
      result.value.should eq 'test'
    end

  end
end