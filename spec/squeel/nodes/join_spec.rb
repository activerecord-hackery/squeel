require 'spec_helper'

module Squeel
  module Nodes
    describe Join do

      before do
        @j = Join.new :name
      end

      it 'defaults to Squeel::InnerJoin' do
        @j._type.should eq Squeel::InnerJoin
      end

      it 'allows setting join type' do
        @j.outer
        @j._type.should eq Squeel::OuterJoin
      end

      it 'allows setting polymorphic class' do
        @j._klass = Person
        @j.should be_polymorphic
        @j._klass.should eq Person
      end

      it 'creates a KeyPath when sent an unknown method' do
        keypath = @j.another
        keypath.should be_a KeyPath
        keypath.path.should eq [@j, Stub.new(:another)]
      end

      it 'creates a KeyPath with a join endpoint when sent a method with a Class param' do
        keypath = @j.another(Person)
        keypath.should be_a KeyPath
        keypath.path.should eq [@j, Join.new(:another, Squeel::InnerJoin, Person)]
      end

      it 'creates an absolute keypath with just an endpoint with ~' do
        node = ~@j
        node.should be_a KeyPath
        node.path.should eq [@j]
      end

    end
  end
end
