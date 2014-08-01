require 'spec_helper'

module Squeel
  module Visitors
    describe Visitor do

      before do
        @jd = new_join_dependency(Person, {
               :children => {
                 :children => {
                   :parent => :parent
                 }
               }
             }, [])
        @c = Squeel::Adapters::ActiveRecord::Context.new(@jd)
        @v = Visitor.new(@c)
      end

      it 'creates a bare Arel attribute given a symbol with no asc/desc' do
        attribute = @v.accept(:name)
        expect(attribute).to be_a Arel::Attribute
        expect(attribute.name).to eq :name
        expect(attribute.relation.name).to eq 'people'
      end

      it 'creates attributes against the proper table for nested hashes' do
        attributes = @v.accept({
          :children => {
            :children => {
              :parent => {
                :parent => :name
              }
            }
          }
        })

        expect(attributes).to be_a Array
        attribute = attributes.first
        expect(attribute).to be_a Arel::Attributes::Attribute
        expect(attribute.relation.table_alias).to eq 'parents_people_2'
      end

      it 'does not alter values it is unable to accept' do
        values = @v.accept(['THIS PARAMETER', 'WHAT DOES IT MEAN???'])
        expect(values).to eq ['THIS PARAMETER', 'WHAT DOES IT MEAN???']
      end

      it 'treats keypath keys like nested hashes' do
        attribute = @v.accept(Nodes::Stub.new(:children).children.parent.parent.name)
        expect(attribute).to be_a Arel::Attributes::Attribute
        expect(attribute.relation.table_alias).to eq 'parents_people_2'
      end

      it 'honors absolute keypaths' do
        attributes = @v.accept(dsl{{children => {children => ~children.children.name}}})
        expect(attributes).to be_a Array
        attribute = attributes.first
        expect(attribute.relation.table_alias).to eq 'children_people_2'
      end

      it 'allows hashes with keypath keys' do
        attributes = @v.accept(Nodes::Stub.new(:children).children.parent.parent => :name)
        expect(attributes).to be_a Array
        attribute = attributes.first
        expect(attribute).to be_a Arel::Attributes::Attribute
        expect(attribute.relation.table_alias).to eq 'parents_people_2'
      end

      it 'allows a subquery as a selection' do
        relation = Person.where(:name => 'Aric Smith').select(:id)
        node = @v.accept(relation.as('aric'))
        expect(node.to_sql).to be_like "(SELECT #{Q}people#{Q}.#{Q}id#{Q} FROM #{Q}people#{Q}  WHERE #{Q}people#{Q}.#{Q}name#{Q} = 'Aric Smith') aric"
      end

      it 'creates an Arel NamedFunction node for a Function node' do
        function = @v.accept(:find_in_set.func())
        expect(function).to be_a Arel::Nodes::NamedFunction
      end

      it 'maps symbols in Function args to Arel attributes' do
        function = @v.accept(:find_in_set.func(:id, '1,2,3'))
        expect(function.to_sql).to match /find_in_set\(#{Q}people#{Q}.#{Q}id#{Q}, '1,2,3'\)/
      end

      it 'accepts keypaths as function args' do
        function = @v.accept(dsl{find_in_set(children.children.id, '1,2,3')})
        expect(function.to_sql).to match /find_in_set\(#{Q}children_people_2#{Q}.#{Q}id#{Q}, '1,2,3'\)/
      end

      it 'sets the alias on the Arel NamedFunction from the Function alias' do
        function = @v.accept(:find_in_set.func(:id, '1,2,3').as('newname'))
        expect(function.to_sql).to match /newname/
      end

      it 'accepts As nodes containing symbols' do
        as = @v.accept(:name.as('other_name'))
        expect(as.to_sql).to match /#{Q}people#{Q}.#{Q}name#{Q} AS other_name/
      end

      it 'accepts As nodes containing stubs' do
        as = @v.accept(dsl{name.as(other_name)})
        expect(as.to_sql).to match /#{Q}people#{Q}.#{Q}name#{Q} AS other_name/
      end

      it 'accepts As nodes containing keypaths' do
        as = @v.accept(dsl{children.name.as(other_name)})
        expect(as.to_sql).to match /#{Q}children_people#{Q}.#{Q}name#{Q} AS other_name/
      end

      it 'creates an Arel Grouping node for a Squeel Grouping node' do
        grouping = @v.accept(dsl{_(id)})
        expect(grouping).to be_a Arel::Nodes::Grouping
      end

      it 'creates an Arel Addition node for an Operation node with + as operator' do
        operation = @v.accept(dsl{id + 1})
        expect(operation).to be_a Arel::Nodes::Addition
      end

      it 'creates an Arel Subtraction node for an Operation node with - as operator' do
        operation = @v.accept(dsl{id - 1})
        expect(operation).to be_a Arel::Nodes::Subtraction
      end

      it 'creates an Arel Multiplication node for an Operation node with * as operator' do
        operation = @v.accept(dsl{id * 1})
        expect(operation).to be_a Arel::Nodes::Multiplication
      end

      it 'creates an Arel Division node for an Operation node with / as operator' do
        operation = @v.accept(dsl{id / 1})
        expect(operation).to be_a Arel::Nodes::Division
      end

      it 'sets the alias on an InfixOperation from the Operation alias' do
        operation = @v.accept(dsl{(id + 1).as(:incremented_id)})
        expect(operation.to_sql).to match /incremented_id/
      end

    end
  end
end
