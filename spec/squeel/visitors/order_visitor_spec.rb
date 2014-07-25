require 'spec_helper'

module Squeel
  module Visitors
    describe OrderVisitor do

      before do
        @jd = new_join_dependency(Person, {
               :children => {
                 :children => {
                   :parent => :parent
                 }
               }
             }, [])
        @c = Squeel::Adapters::ActiveRecord::Context.new(@jd)
        @v = OrderVisitor.new(@c)
      end

      it 'accepts Order with Function expression' do
        function = @v.accept(dsl{find_in_set(children.children.id, '1,2,3').desc})
        expect(function.to_sql).to match /find_in_set\(#{Q}children_people_2#{Q}.#{Q}id#{Q}, '1,2,3'\) DESC/
      end

      it 'accepts Order with Operation expression' do
        operation = @v.accept(dsl{(id / 1).desc})
        expect(operation.to_sql).to match /#{Q}people#{Q}.#{Q}id#{Q} \/ 1 DESC/
      end

      it 'orders by predicates' do
        orders = @v.accept(dsl{name == 'Ernie'})
        expect(orders.to_sql).to match /#{Q}people#{Q}.#{Q}name#{Q} = 'Ernie'/
      end

    end
  end
end
