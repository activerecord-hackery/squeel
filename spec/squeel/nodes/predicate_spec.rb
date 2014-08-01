require 'spec_helper'

module Squeel
  module Nodes
    describe Predicate do

      it 'accepts a value on instantiation' do
        @p = Predicate.new :name, :eq, 'value'
        expect(@p.value).to eq 'value'
      end

      it 'sets value via accessor' do
        @p = Predicate.new :name, :eq
        @p.value = 'value'
        expect(@p.value).to eq 'value'
      end

      it 'sets value via %' do
        @p = Predicate.new :name, :eq
        @p % 'value'
        expect(@p.value).to eq 'value'
      end

      it 'can be inquired for value presence' do
        @p = Predicate.new :name, :eq
        expect(@p.value?).to be false
        @p.value = 'value'
        expect(@p.value?).to be true
      end

      it 'can be ORed with another predicate' do
        left = Predicate.new :name, :eq, 'Joe'
        right = Predicate.new :name, :eq, 'Bob'
        combined = left | right
        expect(combined).to be_a Nodes::Or
        expect(combined.left).to eq left
        expect(combined.right).to eq right
      end

      it 'can be ANDed with another predicate' do
        left = Predicate.new :name, :eq, 'Joe'
        right = Predicate.new :name, :eq, 'Bob'
        combined = left & right
        expect(combined).to be_a Nodes::And
        expect(combined.children).to eq [left, right]
      end

      it 'implements equivalence check' do
        p1 = dsl{name.eq 'blargh'}
        p2 = dsl{name.eq 'blargh'}
        expect([p1, p2].uniq.size).to eq(1)
      end

      it 'can be aliased' do
        aliased = dsl{(name == 'joe').as('zomg_its_joe')}
        expect(aliased).to be_a Squeel::Nodes::As
        expect(aliased.left).to eql dsl{(name == 'joe')}
        expect(aliased.right).to eq 'zomg_its_joe'
      end

    end
  end
end
