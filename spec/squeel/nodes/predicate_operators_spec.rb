require 'spec_helper'

module Squeel
  module Nodes
    describe PredicateOperators do

      describe '&' do
        it 'creates And nodes from hashes' do
          left = {:name.matches => 'J%'}
          right  = {:name.matches => '%e'}
          n = left & right
          expect(n).to be_a And
          expect(n.children).to eq [left, right]
        end

        it 'creates And nodes from predicates' do
          left = :name.matches % 'J%'
          right = :name.matches % '%e'
          n = left & right
          expect(n).to be_a And
          expect(n.children).to eq [left, right]
        end

        it 'creates And nodes by appending a new child' do
          left = :name.matches % 'J%' & :name.matches % '%e'
          right = :id.gt % 0
          expected = left.children + [right]
          new_and = left & right
          expect(new_and).to be_a And
          expect(new_and.children).to eq expected
        end
      end

      describe '|' do
        it 'creates Or nodes from hashes' do
          left = {:name.matches => 'J%'}
          right  = {:name.matches => '%e'}
          n = left | right
          expect(n).to be_a Or
          expect(n.left).to eq left
          expect(n.right).to eq right
        end

        it 'creates Or nodes from predicates' do
          left = :name.matches % 'J%'
          right = :name.matches % '%e'
          n = left | right
          expect(n).to be_a Or
          expect(n.left).to eq left
          expect(n.right).to eq right
        end

        it 'creates Or nodes from other Or nodes' do
          left = :name.matches % 'J%' | :name.matches % '%e'
          right = :id.gt % 0 | :id.lt % 100
          n = left | right
          expect(n).to be_a Or
          expect(n.left).to eq left
          expect(n.right).to eq right
        end
      end

      describe '-@' do
        it 'creates Not nodes from hashes' do
          expr = {:name => 'Joe'}
          n = - expr
          expect(n).to be_a Not
          expect(n.expr).to eq expr
        end

        it 'creates Not nodes from predicates' do
          expr = :name.matches % 'J%'
          n = - expr
          expect(n).to be_a Not
          expect(n.expr).to eq expr
        end

        it 'creates Not nodes from other Not nodes' do
          expr = -(:name.matches % '%e')
          n = - expr
          expect(n).to be_a Not
          expect(n.expr).to eq expr
        end
      end

    end
  end
end
