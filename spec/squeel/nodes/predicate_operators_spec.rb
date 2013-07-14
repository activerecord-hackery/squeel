require 'spec_helper'

module Squeel
  module Nodes
    describe PredicateOperators do

      describe '&' do
        it 'creates And nodes from hashes' do
          left = {:name.matches => 'J%'}
          right  = {:name.matches => '%e'}
          n = left & right
          n.should be_a And
          n.children.should eq [left, right]
        end

        it 'creates And nodes from predicates' do
          left = :name.matches % 'J%'
          right = :name.matches % '%e'
          n = left & right
          n.should be_a And
          n.children.should eq [left, right]
        end

        it 'creates And nodes by appending a new child' do
          left = :name.matches % 'J%' & :name.matches % '%e'
          right = :id.gt % 0
          expected = left.children + [right]
          new_and = left & right
          new_and.should be_a And
          new_and.children.should eq expected
        end
      end

      describe '|' do
        it 'creates Or nodes from hashes' do
          left = {:name.matches => 'J%'}
          right  = {:name.matches => '%e'}
          n = left | right
          n.should be_a Or
          n.left.should eq left
          n.right.should eq right
        end

        it 'creates Or nodes from predicates' do
          left = :name.matches % 'J%'
          right = :name.matches % '%e'
          n = left | right
          n.should be_a Or
          n.left.should eq left
          n.right.should eq right
        end

        it 'creates Or nodes from other Or nodes' do
          left = :name.matches % 'J%' | :name.matches % '%e'
          right = :id.gt % 0 | :id.lt % 100
          n = left | right
          n.should be_a Or
          n.left.should eq left
          n.right.should eq right
        end
      end

      describe '-@' do
        it 'creates Not nodes from hashes' do
          expr = {:name => 'Joe'}
          n = - expr
          n.should be_a Not
          n.expr.should eq expr
        end

        it 'creates Not nodes from predicates' do
          expr = :name.matches % 'J%'
          n = - expr
          n.should be_a Not
          n.expr.should eq expr
        end

        it 'creates Not nodes from other Not nodes' do
          expr = -(:name.matches % '%e')
          n = - expr
          n.should be_a Not
          n.expr.should eq expr
        end
      end

    end
  end
end
