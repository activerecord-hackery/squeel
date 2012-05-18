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

    describe '#my' do
      it 'allows access to caller instance variables' do
        @test_var = "test"
        result = DSL.eval{my{@test_var}}
        result.should be_a String
        result.should eq @test_var
      end

      it 'allows access to caller methods' do
        def test_scoped_method
          :name
        end

        result = DSL.eval{my{test_scoped_method}}
        result.should be_a Symbol
        result.should eq :name
      end
    end

    describe '`string`' do
      it 'creates a Literal' do
        result = dsl{`blah`}
        result.should be_a Nodes::Literal
        result.should eq 'blah'
      end
    end

    describe '#sift' do
      it 'creates a Sifter' do
        result = dsl{sift :blah}
        result.should be_a Nodes::Sifter
        result.name.should eq :blah
      end

      it 'casts Stubs to Symbols for sifter names' do
        result = dsl{sift blah}
        result.should be_a Nodes::Sifter
        result.name.should eq :blah
      end
    end

    describe '#_' do
      it 'creates a Grouping' do
        result = dsl{_(id + 1)}
        result.should be_a Nodes::Grouping
        result.expr.should eq Nodes::Operation.new(:+, Nodes::Stub.new(:id), 1)
      end
    end

  end
end
