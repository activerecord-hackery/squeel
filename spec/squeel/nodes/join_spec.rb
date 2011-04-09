require 'spec_helper'

module Squeel
  module Nodes
    describe Join do

      it 'defaults to Arel::InnerJoin' do
        @j = Join.new :name
        @j.type.should eq Arel::InnerJoin
      end

      it 'allows setting join type' do
        @j = Join.new :name
        @j.outer
        @j.type.should eq Arel::OuterJoin
      end

      it 'allows setting polymorphic class' do
        @j = Join.new :name
        @j.klass = Person
        @j.should be_polymorphic
        @j.klass.should eq Person
      end

    end
  end
end