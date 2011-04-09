module Squeel
  module Visitors
    describe OrderVisitor do

      before do
        @jd = ActiveRecord::Associations::JoinDependency.
             new(Person, {
               :children => {
                 :children => {
                   :parent => :parent
                 }
               }
             }, [])
        @c = Squeel::Contexts::JoinDependencyContext.new(@jd)
        @v = OrderVisitor.new(@c)
      end

      it 'creates a bare ARel attribute given a symbol with no asc/desc' do
        attribute = @v.accept(:name)
        attribute.should be_a Arel::Attribute
        attribute.name.should eq :name
        attribute.relation.name.should eq 'people'
      end

      it 'creates the ordering against the proper table for nested hashes' do
        orders = @v.accept({
          :children => {
            :children => {
              :parent => {
                :parent => :name.asc
              }
            }
          }
        })
        orders.should be_a Array
        ordering = orders.first
        ordering.should be_a Arel::Nodes::Ordering
        ordering.expr.relation.table_alias.should eq 'parents_people_2'
        ordering.direction.should eq :asc
      end

      it 'does not alter values it is unable to accept' do
        orders = @v.accept(['THIS PARAMETER', 'WHAT DOES IT MEAN???'])
        orders.should eq ['THIS PARAMETER', 'WHAT DOES IT MEAN???']
      end

      it 'treats keypath keys like nested hashes' do
        ordering = @v.accept(Nodes::Stub.new(:children).children.parent.parent.name.asc)
        ordering.should be_a Arel::Nodes::Ordering
        ordering.expr.relation.table_alias.should eq 'parents_people_2'
        ordering.direction.should eq :asc
      end

      it 'honors absolute keypaths' do
        orders = @v.accept(dsl{{children => {children => ~children.children.name.asc}}})
        orders.should be_a Array
        ordering = orders.first
        ordering.expr.relation.table_alias.should eq 'children_people_2'
        ordering.direction.should eq :asc
      end

      it 'allows hashes with keypath keys' do
        orders = @v.accept(Nodes::Stub.new(:children).children.parent.parent => :name.asc)
        orders.should be_a Array
        ordering = orders.first
        ordering.should be_a Arel::Nodes::Ordering
        ordering.expr.relation.table_alias.should eq 'parents_people_2'
        ordering.direction.should eq :asc
      end

      it 'creates an ARel NamedFunction node for a Function node' do
        function = @v.accept(:find_in_set.func())
        function.should be_a Arel::Nodes::NamedFunction
      end

      it 'maps symbols in Function args to ARel attributes' do
        function = @v.accept(:find_in_set.func(:id, '1,2,3'))
        function.to_sql.should match /find_in_set\("people"."id", '1,2,3'\)/
      end

      it 'accepts Order with Function expression' do
        function = @v.accept(dsl{find_in_set(children.children.id, '1,2,3').desc})
        function.to_sql.should match /find_in_set\("children_people_2"."id", '1,2,3'\) DESC/
      end

      it 'accepts keypaths as function args' do
        function = @v.accept(dsl{find_in_set(children.children.id, '1,2,3')})
        function.to_sql.should match /find_in_set\("children_people_2"."id", '1,2,3'\)/
      end

      it 'sets the alias on the ARel NamedFunction from the Function alias' do
        function = @v.accept(:find_in_set.func(:id, '1,2,3').as('newname'))
        function.to_sql.should match /newname/
      end

      it 'creates an ARel Addition node for an Operation node with + as operator' do
        operation = @v.accept(dsl{id + 1})
        operation.should be_a Arel::Nodes::Addition
      end

      it 'creates an ARel Subtraction node for an Operation node with - as operator' do
        operation = @v.accept(dsl{id - 1})
        operation.should be_a Arel::Nodes::Subtraction
      end

      it 'creates an ARel Multiplication node for an Operation node with * as operator' do
        operation = @v.accept(dsl{id * 1})
        operation.should be_a Arel::Nodes::Multiplication
      end

      it 'creates an ARel Division node for an Operation node with / as operator' do
        operation = @v.accept(dsl{id / 1})
        operation.should be_a Arel::Nodes::Division
      end

      it 'sets the alias on an InfixOperation from the Operation alias' do
        operation = @v.accept(dsl{(id + 1).as(:incremented_id)})
        operation.to_sql.should match /incremented_id/
      end

      it 'accepts Order with Operation expression' do
        operation = @v.accept(dsl{(id / 1).desc})
        operation.to_sql.should match /"people"."id" \/ 1 DESC/
      end

    end
  end
end