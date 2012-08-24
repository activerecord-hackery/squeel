require 'spec_helper'

module Squeel
  module Nodes
    describe Order do

      it 'requires a direction of -1 or 1' do
        expect { Order.new :attribute, 0 }.to raise_error ArgumentError
      end

      it 'defaults to ascending order' do
        @o = Order.new :attribute
        @o.should be_ascending
      end

      it 'allows reversal of order' do
        @o = Order.new :attribute, 1
        @o.reverse!
        @o.should be_descending
      end

      it 'allows setting order' do
        @o = Order.new :attribute
        @o.desc
        @o.should be_descending
      end

      it 'implements equivalence check' do
        array = [Order.new(:attribute, 1), Order.new(:attribute, 1)]
        array.uniq.should have(1).order
      end

    end
  end
end
