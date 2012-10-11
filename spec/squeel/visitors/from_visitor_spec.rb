require 'spec_helper'

module Squeel
  module Visitors
    describe FromVisitor do

      before do
        @jd = new_join_dependency(Person, {}, [])
        @c = Squeel::Adapters::ActiveRecord::Context.new(@jd)
        @v = FromVisitor.new(@c)
      end

      it 'allows strings' do
        from = @v.accept('people')
        from.should eq 'people'
      end

    end
  end
end
