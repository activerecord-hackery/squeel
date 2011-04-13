require 'spec_helper'

module Squeel
  module Visitors
    describe PredicateVisitor do

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
        @v = PredicateVisitor.new(@c)
      end

      it 'creates Equality nodes for simple hashes' do
        predicate = @v.accept(:name => 'Joe')
        predicate.should be_a Arel::Nodes::Equality
        predicate.left.name.should eq :name
        predicate.right.should eq 'Joe'
      end

      it 'creates In nodes for simple hashes with an array as a value' do
        predicate = @v.accept(:name => ['Joe', 'Bob'])
        predicate.should be_a Arel::Nodes::In
        predicate.left.name.should eq :name
        predicate.right.should eq ['Joe', 'Bob']
      end

      it 'creates the node against the proper table for nested hashes' do
        predicate = @v.accept({
          :children => {
            :children => {
              :parent => {
                :parent => {
                  :name => 'Joe'
                }
              }
            }
          }
        })
        predicate.should be_a Arel::Nodes::Equality
        predicate.left.relation.table_alias.should eq 'parents_people_2'
        predicate.right.should eq 'Joe'
      end

      it 'treats keypath keys like nested hashes' do
        standard = @v.accept({
          :children => {
            :children => {
              :parent => {
                :parent => {
                  :name => 'Joe'
                }
              }
            }
          }
        })
        keypath = @v.accept(Nodes::Stub.new(:children).children.parent.parent.name => 'Joe')
        keypath.to_sql.should eq standard.to_sql
      end

      it 'honors absolute keypaths' do
        standard = @v.accept({
          :children => {
            :children => {
              :name => 'Joe'
            }
          }
        })
        keypath = @v.accept(dsl{{children => {children => {~children.children.name => 'Joe'}}}})
        keypath.to_sql.should eq standard.to_sql
      end

      it 'allows incomplete predicates (missing value) as keys' do
        standard = @v.accept({
          :children => {
            :children => {
              :parent => {
                :parent => {
                  :name.matches => 'Joe%'
                }
              }
            }
          }
        })
        keypath = @v.accept(Nodes::Stub.new(:children).children.parent.parent.name.matches => 'Joe%')
        keypath.to_sql.should eq standard.to_sql
      end

      it 'allows hashes as values with keypath keys' do
        standard = @v.accept({
          :children => {
            :children => {
              :parent => {
                :parent => {
                  :name => 'Joe'
                }
              }
            }
          }
        })
        keypath = @v.accept(Nodes::Stub.new(:children).children.parent.parent => {:name => 'Joe'})
        keypath.to_sql.should eq standard.to_sql
      end

      it 'contextualizes Stub values' do
        predicate = @v.accept(dsl{{name => name}})
        predicate.should be_a Arel::Nodes::Equality
        predicate.right.should be_a Arel::Attribute
        predicate.to_sql.should match /"people"."name" = "people"."name"/
      end

      it 'contextualizes Symbol values' do
        predicate = @v.accept(:name => :name)
        predicate.should be_a Arel::Nodes::Equality
        predicate.right.should be_a Arel::Attribute
        predicate.to_sql.should match /"people"."name" = "people"."name"/
      end

      it 'contextualizes KeyPath values in hashes' do
        predicate = @v.accept(dsl{{name => children.name}})
        predicate.should be_a Arel::Nodes::Equality
        predicate.right.should be_a Arel::Attribute
        predicate.to_sql.should match /"people"."name" = "children_people"."name"/
      end

      it 'contextualizes KeyPath values in predicates' do
        predicate = @v.accept(dsl{name == children.name})
        predicate.should be_a Arel::Nodes::Equality
        predicate.right.should be_a Arel::Attribute
        predicate.to_sql.should match /"people"."name" = "children_people"."name"/
      end

      it 'visits ActiveRecord::Relation values in predicates' do
        predicate = @v.accept(dsl{id >> Person.select{id}.limit(3).order{id.desc}})
        predicate.should be_a Arel::Nodes::In
        predicate.right.should be_a Arel::Nodes::SelectStatement
        predicate.to_sql.should match /"people"."id" IN \(SELECT  "people"."id" FROM "people"  ORDER BY "people"."id" DESC LIMIT 3\)/
      end

      it "doesn't try to sanitize_sql an array of strings in the value of a Predicate" do
        predicate = @v.accept(dsl{name >> ['Aric Smith', 'Gladyce Kulas']})
        predicate.should be_a Arel::Nodes::In
        predicate.right.should be_an Array
        predicate.to_sql.should match /"people"."name" IN \('Aric Smith', 'Gladyce Kulas'\)/
      end

      it 'creates a node of the proper type when a hash has a Predicate as a key' do
        predicate = @v.accept(:name.matches => 'Joe%')
        predicate.should be_a Arel::Nodes::Matches
        predicate.left.name.should eq :name
        predicate.right.should eq 'Joe%'
      end

      it 'treats hash keys as an association when there is an array of "acceptables" on the value side' do
        predicate = @v.accept(:children => [:name.matches % 'Joe%', :name.eq % 'Bob'])
        predicate.should be_a Arel::Nodes::Grouping
        predicate.expr.should be_a Arel::Nodes::And
        predicate.expr.children.should have(2).items
        predicate.expr.children.first.should be_a Arel::Nodes::Matches
        predicate.expr.children.first.left.relation.table_alias.should eq 'children_people'
      end

      it 'treats hash keys as an association when there is an Or on the value side' do
        predicate = @v.accept(:children => (:name.matches % 'Joe%' | :name.matches % 'Bob%'))
        predicate.should be_a Arel::Nodes::Grouping
        predicate.expr.should be_a Arel::Nodes::Or
        predicate.expr.left.should be_a Arel::Nodes::Matches
        predicate.expr.left.left.relation.table_alias.should eq 'children_people'
      end

      it 'treats hash keys as an association when there is an And on the value side' do
        predicate = @v.accept(:children => (:name.matches % 'Joe%' & :name.matches % 'Bob%'))
        predicate.should be_a Arel::Nodes::Grouping
        predicate.expr.should be_a Arel::Nodes::And
        predicate.expr.children.should have(2).items
        predicate.expr.children.first.should be_a Arel::Nodes::Matches
        predicate.expr.children.first.left.relation.table_alias.should eq 'children_people'
      end

      it 'treats hash keys as an association when there is a Not on the value side' do
        predicate = @v.accept(:children => -(:name.matches % 'Joe%'))
        predicate.should be_a Arel::Nodes::Not
        predicate.expr.should be_a Arel::Nodes::Matches
        predicate.expr.left.relation.table_alias.should eq 'children_people'
      end

      it 'treats hash keys as an association when there is a Predicate on the value side' do
        predicate = @v.accept(:children => (:name.matches % 'Joe%'))
        predicate.should be_a Arel::Nodes::Matches
        predicate.left.relation.table_alias.should eq 'children_people'
      end

      it 'treats hash keys as an association when there is a KeyPath on the value side' do
        predicate = @v.accept(:children => Nodes::Stub.new(:children).name.eq('Joe'))
        predicate.should be_a Arel::Nodes::Equality
        predicate.left.relation.table_alias.should eq 'children_people_2'
        predicate.left.name.should eq :name
        predicate.right.should eq 'Joe'
      end

      it 'creates an ARel Grouping node containing an Or node for Or nodes' do
        left = :name.matches % 'Joe%'
        right = :id.gt % 1
        predicate = @v.accept(left | right)
        predicate.should be_a Arel::Nodes::Grouping
        predicate.expr.should be_a Arel::Nodes::Or
        predicate.expr.left.should be_a Arel::Nodes::Matches
        predicate.expr.right.should be_a Arel::Nodes::GreaterThan
      end

      it 'creates an ARel Not node for a Not node' do
        expr = -(:name.matches % 'Joe%')
        predicate = @v.accept(expr)
        predicate.should be_a Arel::Nodes::Not
      end

      it 'creates an ARel NamedFunction node for a Function node' do
        function = @v.accept(:find_in_set.func())
        function.should be_a Arel::Nodes::NamedFunction
      end

      it 'maps symbols in Function args to ARel attributes' do
        function = @v.accept(:find_in_set.func(:id, '1,2,3'))
        function.to_sql.should match /"people"."id"/
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

      context 'with polymorphic joins in the JoinDependency' do
        before do
          @jd = ActiveRecord::Associations::JoinDependency.
                new(Note, dsl{[notable(Article), notable(Person)]}, [])
          @c = Squeel::Contexts::JoinDependencyContext.new(@jd)
          @v = PredicateVisitor.new(@c)
        end

        it 'respects the polymorphic class in conditions' do
          article_predicate = @v.accept dsl{{notable(Article) => {:title => 'Hello world!'}}}
          person_predicate = @v.accept dsl{{notable(Person) => {:name => 'Ernie'}}}
          article_predicate.left.relation.name.should eq 'articles'
          person_predicate.left.relation.name.should eq 'people'
        end
      end

    end
  end
end