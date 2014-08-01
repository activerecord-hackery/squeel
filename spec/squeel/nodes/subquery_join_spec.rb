require 'spec_helper'

module Squeel
  module Nodes
    describe SubqueryJoin do
      before(:each) do
        @j =
          if activerecord_version_at_least('4.1.0')
            SubqueryJoin.new(OrderItem.all.as('items'), dsl {(items.orderable_id == id) & (items.orderable_type == 'Seat')} )
          else
            SubqueryJoin.new(OrderItem.scoped.as('items'), dsl {(items.orderable_id == id) & (items.orderable_type == 'Seat')} )
          end
      end

      it 'defaults to Squeel::InnerJoin' do
        expect(@j.type).to eq Squeel::InnerJoin
      end

      it 'allows setting join type' do
        @j.outer
        expect(@j.type).to eq Squeel::OuterJoin
      end

      it 'subquery should be a Nodes::As' do
        expect(@j.subquery).to be_kind_of(As)
      end

      it 'constraints should be a node' do
        expect(@j.constraints).to be_kind_of(Node)
      end

      it 'only convert an ActiveRecord::Relation to a SubqueryJoin' do
        j =
          if activerecord_version_at_least('4.1.0')
            OrderItem.all.as('items').on{(items.orderable_id == id) & (items.orderable_type == 'Seat')}
          else
            OrderItem.scoped.as('items').on{(items.orderable_id == id) & (items.orderable_type == 'Seat')}
          end

        expect(j).to be_kind_of(SubqueryJoin)

        expect { As.new('name', 'alias').on{(items.orderable_id == id) & (items.orderable_type == 'Seat')} }.to raise_error
      end
    end
  end
end
