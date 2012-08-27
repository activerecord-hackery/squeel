require 'spec_helper'

module Squeel
  module Visitors
    describe PreloadVisitor do

      before do
        @v = PreloadVisitor.new
      end

      it 'returns symbols unmodified' do
        @v.accept(:blah).should eq :blah
      end

      it 'converts stubs to symbols' do
        @v.accept(dsl{blah}).should eq :blah
      end

      it 'converts joins to their names' do
        @v.accept(dsl{blah(Article)}).should eq :blah
      end

      it 'converts keypaths to their hash equivalents' do
        @v.accept(dsl{one.two.three.four}).should eq({
          :one => {:two => {:three => :four}}
        })
      end

      it 'visits hashes' do
        @v.accept(dsl{{
          blah1 => {blah2(Article) => blah3}
        }}).should eq({:blah1 => {:blah2 => :blah3}})
      end

      it 'visits arrays' do
        @v.accept(dsl{[{
          blah1 => {blah2(Article) => blah3}
        }]}).should eq([{:blah1 => {:blah2 => :blah3}}])
      end

    end
  end
end
