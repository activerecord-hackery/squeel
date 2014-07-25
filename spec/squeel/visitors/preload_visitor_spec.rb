require 'spec_helper'

module Squeel
  module Visitors
    describe PreloadVisitor do

      before do
        @v = PreloadVisitor.new
      end

      it 'returns symbols unmodified' do
        expect(@v.accept(:blah)).to eq :blah
      end

      it 'converts stubs to symbols' do
        expect(@v.accept(dsl{blah})).to eq :blah
      end

      it 'converts joins to their names' do
        expect(@v.accept(dsl{blah(Article)})).to eq :blah
      end

      it 'converts keypaths to their hash equivalents' do
        expect(@v.accept(dsl{one.two.three.four})).to eq({
          :one => {:two => {:three => :four}}
        })
      end

      it 'visits hashes' do
        expect(@v.accept(dsl{{
          blah1 => {blah2(Article) => blah3}
        }})).to eq({:blah1 => {:blah2 => :blah3}})
      end

      it 'visits arrays' do
        expect(@v.accept(dsl{[{
          blah1 => {blah2(Article) => blah3}
        }]})).to eq([{:blah1 => {:blah2 => :blah3}}])
      end

    end
  end
end
