require 'spec_helper'

module Squeel
  module Nodes
    describe Predicate do

      it 'accepts a value on instantiation' do
        @p = Predicate.new :name, :eq, 'value'
        @p.value.should eq 'value'
      end

      it 'sets value via accessor' do
        @p = Predicate.new :name, :eq
        @p.value = 'value'
        @p.value.should eq 'value'
      end

      it 'sets value via %' do
        @p = Predicate.new :name, :eq
        @p % 'value'
        @p.value.should eq 'value'
      end

      it 'can be inquired for value presence' do
        @p = Predicate.new :name, :eq
        @p.value?.should be_false
        @p.value = 'value'
        @p.value?.should be_true
      end

      it 'can be ORed with another predicate' do
        left = Predicate.new :name, :eq, 'Joe'
        right = Predicate.new :name, :eq, 'Bob'
        combined = left | right
        combined.should be_a Nodes::Or
        combined.left.should eq left
        combined.right.should eq right
      end

      it 'can be ANDed with another predicate' do
        left = Predicate.new :name, :eq, 'Joe'
        right = Predicate.new :name, :eq, 'Bob'
        combined = left & right
        combined.should be_a Nodes::And
        combined.children.should eq [left, right]
      end

      it 'implements equivalence check' do
        p1 = dsl{name.eq 'blargh'}
        p2 = dsl{name.eq 'blargh'}
        [p1, p2].uniq.should have(1).predicate
      end

      it 'can be aliased' do
        aliased = dsl{(name == 'joe').as('zomg_its_joe')}
        aliased.should be_a Squeel::Nodes::As
        aliased.left.should eql dsl{(name == 'joe')}
        aliased.right.should eq 'zomg_its_joe'
      end

    end
  end
end
