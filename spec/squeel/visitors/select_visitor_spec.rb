require 'spec_helper'

module Squeel
  module Visitors
    describe SelectVisitor do

      before do
        @jd = new_join_dependency(Person, {
               :children => {
                 :children => {
                   :parent => :parent
                 }
               }
             }, [])
        @c = Squeel::Adapters::ActiveRecord::Context.new(@jd)
        @v = SelectVisitor.new(@c)
      end

      it 'selects predicates' do
        selects = @v.accept(dsl{name == 'Ernie'})
        selects.to_sql.should match /#{Q}people#{Q}.#{Q}name#{Q} = 'Ernie'/
      end

    end
  end
end
