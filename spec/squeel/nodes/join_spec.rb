require 'spec_helper'

module Squeel
  module Nodes
    describe Join do

      before do
        @j = Join.new :name
      end

      it 'defaults to Arel::InnerJoin' do
        @j.type.should eq Arel::InnerJoin
      end

      it 'allows setting join type' do
        @j.outer
        @j.type.should eq Arel::OuterJoin
      end

      it 'allows setting polymorphic class' do
        @j.klass = Person
        @j.should be_polymorphic
        @j.klass.should eq Person
      end

      it 'creates a KeyPath when sent an unknown method' do
        keypath = @j.another
        keypath.should be_a KeyPath
        keypath.path_with_endpoint.should eq [@j, Stub.new(:another)]
      end

      it 'creates a KeyPath with a join endpoint when sent a method with a Class param' do
        keypath = @j.another(Person)
        keypath.should be_a KeyPath
        keypath.path_with_endpoint.should eq [@j, Join.new(:another, Arel::InnerJoin, Person)]
      end

    end
  end
end