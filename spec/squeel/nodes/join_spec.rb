require 'spec_helper'

module Squeel
  module Nodes
    describe Join do

      before do
        @j = Join.new :name
      end

      it 'defaults to Squeel::InnerJoin' do
        expect(@j._type).to eq Squeel::InnerJoin
      end

      it 'allows setting join type' do
        @j.outer
        expect(@j._type).to eq Squeel::OuterJoin
      end

      it 'allows setting polymorphic class' do
        @j._klass = Person
        expect(@j).to be_polymorphic
        expect(@j._klass).to eq Person
      end

      it 'creates a KeyPath when sent an unknown method' do
        keypath = @j.another
        expect(keypath).to be_a KeyPath
        expect(keypath.path).to eq [@j, Stub.new(:another)]
      end

      it 'creates a KeyPath with a join endpoint when sent a method with a Class param' do
        keypath = @j.another(Person)
        expect(keypath).to be_a KeyPath
        expect(keypath.path).to eq [@j, Join.new(:another, Squeel::InnerJoin, Person)]
      end

      it 'creates an absolute keypath with just an endpoint with ~' do
        node = ~@j
        expect(node).to be_a KeyPath
        expect(node.path).to eq [@j]
      end

    end
  end
end
