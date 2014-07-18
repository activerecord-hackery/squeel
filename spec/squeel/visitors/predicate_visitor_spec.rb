require 'spec_helper'

module Squeel
  module Visitors
    describe PredicateVisitor do

      before do
        @jd = new_join_dependency(Person, {
               :children => {
                 :children => {
                   :parent => :parent
                 }
               }
             }, [])
        @c = Squeel::Adapters::ActiveRecord::Context.new(@jd)
        @v = PredicateVisitor.new(@c)
      end

      it 'does not quote Arel::SelectManager values in Predicate nodes' do
        predicate = Nodes::Predicate.new(Nodes::Function.new(:blah, [1, 2]), :in, Person.select(:id).arel)
        node = @v.accept(predicate)
        node.should be_a Arel::Nodes::In
        node.right.should be_a Arel::Nodes::SelectStatement
      end

      it 'quote nil values in Predicate nodes' do
        predicate = Nodes::Predicate.new(Nodes::Function.new(:blah, [1, 2]), :in, nil)
        node = @v.accept(predicate)
        node.should be_a Arel::Nodes::In
        if defined?(Arel::Nodes::Quoted)
          node.right.expr.should == 'NULL'
        else
          node.right.should be_nil
        end

      end

      it 'creates Equality nodes for simple hashes' do
        predicate = @v.accept(:name => 'Joe')
        predicate.should be_a Arel::Nodes::Equality
        predicate.left.name.to_s.should eq 'name'
        if defined?(Arel::Nodes::Casted)
          predicate.right.val.should eq 'Joe'
        else
          predicate.right.should eq 'Joe'
        end
      end

      it 'creates In nodes for simple hashes with an array as a value' do
        predicate = @v.accept(:name => ['Joe', 'Bob'])
        predicate.should be_a Arel::Nodes::In
        predicate.left.name.to_s.should eq 'name'
        if defined?(Arel::Nodes::Casted)
          predicate.right.map(&:val).should eq ['Joe', 'Bob']
        else
          predicate.right.should eq ['Joe', 'Bob']
        end
      end

      it 'generates "1=0" when given an empty array value in a hash' do
        predicate = @v.accept(:id => [])
        predicate.should be_a Arel::Nodes::SqlLiteral
        predicate.should eq '1=0'
      end

      it 'generates "1=0" for in predicates when given an empty array value' do
        predicate = @v.accept(:id.in => [])
        predicate.should be_a Arel::Nodes::SqlLiteral
        predicate.should eq '1=0'
      end

      it 'generates "1=1" for not_in predicates when given an empty array value' do
        predicate = @v.accept(:id.not_in => [])
        predicate.should be_a Arel::Nodes::SqlLiteral
        predicate.should eq '1=1'
      end

      it 'visits Grouping nodes' do
        predicate = @v.accept(dsl{_(`foo`)})
        predicate.should be_a Arel::Nodes::Grouping
        predicate.to_sql.should eq '(foo)'
      end

      it 'visits Grouping nodes on the attribute side of predicates' do
        predicate = @v.accept(dsl{_(`foo`) == `foo`})
        predicate.should be_a Arel::Nodes::Equality
        predicate.to_sql.should eq '(foo) = foo'
      end

      it 'visits operations containing Grouping nodes' do
        predicate = @v.accept(dsl{_(1) + _(1) == 2})
        predicate.should be_a Arel::Nodes::Equality
        predicate.to_sql.should eq '(1) + (1) = 2'
      end

      it 'creates OR nodes against a Literal' do
        predicate = @v.accept(dsl{`blah` | `blah`})
        predicate.should be_a Arel::Nodes::Grouping
        predicate.to_sql.should eq '(blah OR blah)'
      end

      it 'generates IS NULL for hash keys with a value of [nil]' do
        predicate = @v.accept(:id => [nil])
        predicate.to_sql.should be_like "#{Q}people#{Q}.#{Q}id#{Q} IS NULL"
      end

      it 'generates IS NULL for in predicates with a value of [nil]' do
        predicate = @v.accept(:id.in => [nil])
        predicate.to_sql.should be_like "#{Q}people#{Q}.#{Q}id#{Q} IS NULL"
      end

      it 'generates IS NOT NULL for not_in predicates with a value of [nil]' do
        predicate = @v.accept(:id.not_in => [nil])
        predicate.to_sql.should be_like "#{Q}people#{Q}.#{Q}id#{Q} IS NOT NULL"
      end

      it 'generates IN OR IS NULL for hash keys with a value of [1, 2, 3, nil]' do
        predicate = @v.accept(:id => [1, 2, 3, nil])
        predicate.to_sql.should be_like "(#{Q}people#{Q}.#{Q}id#{Q} IN (1, 2, 3) OR #{Q}people#{Q}.#{Q}id#{Q} IS NULL)"
      end

      it 'generates IN OR IS NULL for in predicates with a value of [1, 2, 3, nil]' do
        predicate = @v.accept(:id.in => [1, 2, 3, nil])
        predicate.to_sql.should be_like "(#{Q}people#{Q}.#{Q}id#{Q} IN (1, 2, 3) OR #{Q}people#{Q}.#{Q}id#{Q} IS NULL)"
      end

      it 'generates IN AND IS NOT NULL for not_in predicates with a value of [1, 2, 3, nil]' do
        predicate = @v.accept(:id.not_in => [1, 2, 3, nil])
        predicate.to_sql.should be_like "#{Q}people#{Q}.#{Q}id#{Q} NOT IN (1, 2, 3) AND #{Q}people#{Q}.#{Q}id#{Q} IS NOT NULL"
      end

      it 'allows a subquery on the value side of an explicit predicate' do
        predicate = @v.accept dsl{name.in(Person.select{name}.where{name.in(['Aric Smith', 'Gladyce Kulas'])})}
        predicate.should be_a Arel::Nodes::In
        predicate.left.name.to_s.should eq 'name'
        predicate.right.should be_a Arel::Nodes::SelectStatement
      end

      it 'allows a subquery on the value side of an implicit predicate' do
        predicate = @v.accept(:name => Person.select{name}.where{name.in(['Aric Smith', 'Gladyce Kulas'])})
        predicate.should be_a Arel::Nodes::In
        predicate.left.name.to_s.should eq 'name'
        predicate.right.should be_a Arel::Nodes::SelectStatement
      end

      it 'selects the primary key of a relation with no select_values with an explicit predicate' do
        predicate = @v.accept dsl{name.in(PersonWithNamePrimaryKey.where{name.in(['Aric Smith', 'Gladyce Kulas'])})}
        predicate.right.should be_a Arel::Nodes::SelectStatement
        predicate.right.to_sql.should match /SELECT #{Q}people#{Q}.#{Q}name#{Q}/
      end

      it 'selects the primary key of a relation with no select_values with an implicit predicate' do
        predicate = @v.accept(:name => PersonWithNamePrimaryKey.where{name.in(['Aric Smith', 'Gladyce Kulas'])})
        predicate.right.should be_a Arel::Nodes::SelectStatement
        predicate.right.to_sql.should match /SELECT #{Q}people#{Q}.#{Q}name#{Q}/
      end

      it "doesn't clobber a relation value's existing select_values if present with an explicit predicate" do
        predicate = @v.accept dsl{name.in(Person.select{name})}
        predicate.right.should be_a Arel::Nodes::SelectStatement
        predicate.right.to_sql.should match /SELECT #{Q}people#{Q}.#{Q}name#{Q}/
      end

      it "doesn't clobber a relation value's existing select_values if present with an implicit predicate" do
        predicate = @v.accept(:name => Person.select{name})
        predicate.right.should be_a Arel::Nodes::SelectStatement
        predicate.right.to_sql.should match /SELECT #{Q}people#{Q}.#{Q}name#{Q}/
      end

      it 'converts ActiveRecord::Base objects to their id' do
        predicate = @v.accept(:id => Person.first)
        predicate.should be_a Arel::Nodes::Equality
        predicate.left.name.to_s.should eq 'id'
        if defined?(Arel::Nodes::Casted)
          predicate.right.val.should eq 1
        else
          predicate.right.should eq 1
        end
      end

      it 'converts arrays of ActiveRecord::Base objects to their ids' do
        predicate = @v.accept(:id => [Person.first, Person.last])
        predicate.should be_a Arel::Nodes::In
        predicate.left.name.to_s.should eq 'id'
        if defined?(Arel::Nodes::Casted)
          predicate.right.map(&:val).should eq [Person.first.id, Person.last.id]
        else
          predicate.right.should eq [Person.first.id, Person.last.id]
        end
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
        if defined?(Arel::Nodes::Casted)
          predicate.right.val.should eq 'Joe'
        else
          predicate.right.should eq 'Joe'
        end
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

      it 'honors absolute keypaths with only an endpoint' do
        standard = @v.accept({:name => 'Joe'})
        keypath = @v.accept(dsl{{children => {children => {~name => 'Joe'}}}})
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
        predicate.to_sql.should match /#{Q}people#{Q}.#{Q}name#{Q} = #{Q}people#{Q}.#{Q}name#{Q}/
      end

      it 'contextualizes Symbol values' do
        predicate = @v.accept(:name => :name)
        predicate.should be_a Arel::Nodes::Equality
        predicate.right.should be_a Arel::Attribute
        predicate.to_sql.should match /#{Q}people#{Q}.#{Q}name#{Q} = #{Q}people#{Q}.#{Q}name#{Q}/
      end

      it 'contextualizes KeyPath values in hashes' do
        predicate = @v.accept(dsl{{name => children.name}})
        predicate.should be_a Arel::Nodes::Equality
        predicate.right.should be_a Arel::Attribute
        predicate.to_sql.should match /#{Q}people#{Q}.#{Q}name#{Q} = #{Q}children_people#{Q}.#{Q}name#{Q}/
      end

      it 'contextualizes KeyPath values in predicates' do
        predicate = @v.accept(dsl{name == children.name})
        predicate.should be_a Arel::Nodes::Equality
        predicate.right.should be_a Arel::Attribute
        predicate.to_sql.should match /#{Q}people#{Q}.#{Q}name#{Q} = #{Q}children_people#{Q}.#{Q}name#{Q}/
      end

      it 'visits Squeel Sifters at top level' do
        predicate = @v.accept(dsl {sift :name_starts_or_ends_with, 'smith'})
        predicate.should be_a Arel::Nodes::Grouping
        expr = predicate.expr
        expr.should be_a Arel::Nodes::Or
        expr.left.to_sql.should match /#{Q}people#{Q}.#{Q}name#{Q} [I]*LIKE 'smith%'/
        expr.right.to_sql.should match /#{Q}people#{Q}.#{Q}name#{Q} [I]*LIKE '%smith'/
      end

      it 'visits nested Squeel sifters' do
        predicate = @v.accept(dsl {{:children => sift(:name_starts_or_ends_with, 'smith')}})
        predicate.should be_a Arel::Nodes::Grouping
        expr = predicate.expr
        expr.should be_a Arel::Nodes::Or
        expr.left.to_sql.should match /#{Q}children_people#{Q}.#{Q}name#{Q} [I]*LIKE 'smith%'/
        expr.right.to_sql.should match /#{Q}children_people#{Q}.#{Q}name#{Q} [I]*LIKE '%smith'/
      end

      it 'visits sifters in a keypath' do
        predicate = @v.accept(dsl {children.sift(:name_starts_or_ends_with, 'smith')})
        predicate.should be_a Arel::Nodes::Grouping
        expr = predicate.expr
        expr.should be_a Arel::Nodes::Or
        expr.left.to_sql.should match /#{Q}children_people#{Q}.#{Q}name#{Q} [I]*LIKE 'smith%'/
        expr.right.to_sql.should match /#{Q}children_people#{Q}.#{Q}name#{Q} [I]*LIKE '%smith'/
      end

      it 'honors an explicit table in string keys' do
        predicate = @v.accept('things.attribute' => 'retro')
        predicate.should be_a Arel::Nodes::Equality
        predicate.to_sql.should match /#{Q}things#{Q}.#{Q}attribute#{Q} = 'retro'/
      end

      it 'does not allow "table.column" keys after context change' do
        result = @v.accept(:id => {'articles.person_id' => 1})
        result.should be_a Arel::Nodes::Equality
        result.left.should be_a Arel::Attributes::Attribute
        result.left.relation.name.should eq 'id'
        result.left.name.to_s.should eq 'articles.person_id'
      end

      it 'visits ActiveRecord::Relation values in predicates' do
        predicate = @v.accept(dsl{id >> Person.select{id}.limit(3).order{id.desc}})
        predicate.should be_a Arel::Nodes::In
        predicate.right.should be_a Arel::Nodes::SelectStatement
        predicate.to_sql.should be_like "#{Q}people#{Q}.#{Q}id#{Q} IN (SELECT  #{Q}people#{Q}.#{Q}id#{Q} FROM #{Q}people#{Q}  ORDER BY #{Q}people#{Q}.#{Q}id#{Q} DESC LIMIT 3)"
      end

      it 'converts ActiveRecord::Relation values in function arguments to their Arel AST' do
        predicate = @v.accept(dsl{exists(Person.where{name == 'Aric Smith'})})
        predicate.should be_a Arel::Nodes::NamedFunction
        predicate.expressions.first.should be_a Arel::Nodes::SelectStatement
        predicate.to_sql.should be_like "exists(SELECT #{Q}people#{Q}.* FROM #{Q}people#{Q}  WHERE #{Q}people#{Q}.#{Q}name#{Q} = 'Aric Smith')"
      end

      it "doesn't try to sanitize_sql an array of strings in the value of a Predicate" do
        predicate = @v.accept(dsl{name >> ['Aric Smith', 'Gladyce Kulas']})
        predicate.should be_a Arel::Nodes::In
        predicate.right.should be_an Array
        predicate.to_sql.should match /#{Q}people#{Q}.#{Q}name#{Q} IN \('Aric Smith', 'Gladyce Kulas'\)/
      end

      it 'creates a node of the proper type when a hash has a Predicate as a key' do
        predicate = @v.accept(:name.matches => 'Joe%')
        predicate.should be_a Arel::Nodes::Matches
        predicate.left.name.should eq :name
        if defined?(Arel::Nodes::Casted)
          predicate.right.val.should eq 'Joe%'
        else
          predicate.right.should eq 'Joe%'
        end
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
        predicate.left.name.to_s.should eq 'name'
        if defined?(Arel::Nodes::Casted)
        predicate.right.val.should eq 'Joe'
        else
          predicate.right.should eq 'Joe'
        end
      end

      it 'creates an Arel Grouping node containing an Or node for Or nodes' do
        left = :name.matches % 'Joe%'
        right = :id.gt % 1
        predicate = @v.accept(left | right)
        predicate.should be_a Arel::Nodes::Grouping
        predicate.expr.should be_a Arel::Nodes::Or
        predicate.expr.left.should be_a Arel::Nodes::Matches
        predicate.expr.right.should be_a Arel::Nodes::GreaterThan
      end

      it 'creates an Arel Not node for a Not node' do
        expr = -(:name.matches % 'Joe%')
        predicate = @v.accept(expr)
        predicate.should be_a Arel::Nodes::Not
      end

      it 'creates an Arel NamedFunction node for a Function node' do
        function = @v.accept(:find_in_set.func())
        function.should be_a Arel::Nodes::NamedFunction
      end

      it 'maps symbols in Function args to Arel attributes' do
        function = @v.accept(:find_in_set.func(:id, '1,2,3'))
        function.to_sql.should match /#{Q}people#{Q}.#{Q}id#{Q}/
      end

      it 'sets the alias on the Arel NamedFunction from the Function alias' do
        function = @v.accept(:find_in_set.func(:id, '1,2,3').as('newname'))
        function.to_sql.should match /newname/
      end

      it 'accepts As nodes containing symbols' do
        as = @v.accept(:name.as('other_name'))
        as.to_sql.should match /#{Q}people#{Q}.#{Q}name#{Q} AS other_name/
      end

      it 'accepts As nodes containing stubs' do
        as = @v.accept(dsl{name.as(other_name)})
        as.to_sql.should match /#{Q}people#{Q}.#{Q}name#{Q} AS other_name/
      end

      it 'creates an Arel Addition node for an Operation node with + as operator' do
        operation = @v.accept(dsl{id + 1})
        operation.should be_a Arel::Nodes::Addition
      end

      it 'creates an Arel Subtraction node for an Operation node with - as operator' do
        operation = @v.accept(dsl{id - 1})
        operation.should be_a Arel::Nodes::Subtraction
      end

      it 'creates an Arel Multiplication node for an Operation node with * as operator' do
        operation = @v.accept(dsl{id * 1})
        operation.should be_a Arel::Nodes::Multiplication
      end

      it 'creates an Arel Division node for an Operation node with / as operator' do
        operation = @v.accept(dsl{id / 1})
        operation.should be_a Arel::Nodes::Division
      end

      it 'creates an Arel InfixOperation node for an Operation with a custom operator' do
        operation = @v.accept(dsl{id.op(:blah, 1)})
        operation.should be_a Arel::Nodes::InfixOperation
      end

      it 'sets the alias on an InfixOperation from the Operation alias' do
        operation = @v.accept(dsl{(id + 1).as(:incremented_id)})
        operation.to_sql.should match /incremented_id/
      end

      context 'with polymorphic joins in the JoinDependency' do
        before do
          @jd = new_join_dependency(Note, dsl{[notable(Article), notable(Person)]}, [])
          @c = Squeel::Adapters::ActiveRecord::Context.new(@jd)
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
