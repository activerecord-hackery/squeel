require 'spec_helper'

module Squeel
  module Nodes
    describe Order do

      it 'requires a direction of -1 or 1' do
        expect { Order.new :attribute, 0 }.to raise_error ArgumentError
      end

      it 'defaults to ascending order' do
        @o = Order.new :attribute
        expect(@o).to be_ascending
      end

      it 'allows reversal of order' do
        @o = Order.new :attribute, 1
        @o.reverse!
        expect(@o).to be_descending
      end

      it 'allows setting order' do
        @o = Order.new :attribute
        @o.desc
        expect(@o).to be_descending
      end

      it 'implements equivalence check' do
        array = [Order.new(:attribute, 1), Order.new(:attribute, 1)]
        expect(array.uniq.size).to eq(1)
      end

    end
  end
end
