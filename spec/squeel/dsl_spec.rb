require 'spec_helper'

module Squeel
  describe DSL do

    it 'evaluates code' do
      result = DSL.eval { {id => 1} }
      expect(result).to be_a Hash
      expect(result.keys.first).to be_a Nodes::Stub
    end

    it 'creates function nodes when a method has arguments' do
      result = DSL.eval { max(id) }
      expect(result).to be_a Nodes::Function
      expect(result.args).to eq [Nodes::Stub.new(:id)]
    end

    it 'creates polymorphic join nodes when a method has a single class argument' do
      result = DSL.eval { association(Person) }
      expect(result).to be_a Nodes::Join
      expect(result._klass).to eq Person
    end

    it 'handles OR between predicates' do
      result = DSL.eval {(name =~ 'Joe%') | (articles.title =~ 'Hello%')}
      expect(result).to be_a Nodes::Or
      expect(result.left).to be_a Nodes::Predicate
      expect(result.right).to be_a Nodes::KeyPath
      expect(result.right.endpoint).to be_a Nodes::Predicate
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
      expect(result).to be_a Nodes::Predicate
      expect(result.expr).to eq :name
      expect(result.method_name).to eq :matches
      expect(result.value).to be_a Nodes::Stub
      expect(result.value.symbol).to eq :a_method
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
      expect(result).to be_a Nodes::Predicate
      expect(result.expr).to eq :name
      expect(result.method_name).to eq :matches
      expect(result.value).to be_a String
      expect(result.value).to eq 'test'
    end

    describe '#my' do
      it 'allows access to caller instance variables' do
        @test_var = "test"
        result = DSL.eval{my{@test_var}}
        expect(result).to be_a String
        expect(result).to eq @test_var
      end

      it 'allows access to caller methods' do
        def test_scoped_method
          :name
        end

        result = DSL.eval{my{test_scoped_method}}
        expect(result).to be_a Symbol
        expect(result).to eq :name
      end
    end

    describe '`string`' do
      it 'creates a Literal' do
        result = dsl{`blah`}
        expect(result).to be_a Nodes::Literal
        expect(result).to eq 'blah'
      end
    end

    describe '#sift' do
      it 'creates a Sifter' do
        result = dsl{sift :blah}
        expect(result).to be_a Nodes::Sifter
        expect(result.name).to eq :blah
      end

      it 'casts Stubs to Symbols for sifter names' do
        result = dsl{sift blah}
        expect(result).to be_a Nodes::Sifter
        expect(result.name).to eq :blah
      end
    end

    describe '#_' do
      it 'creates a Grouping' do
        result = dsl{_(id + 1)}
        expect(result).to be_a Nodes::Grouping
        expect(result.expr).to eq Nodes::Operation.new(:+, Nodes::Stub.new(:id), 1)
      end
    end

  end
end
