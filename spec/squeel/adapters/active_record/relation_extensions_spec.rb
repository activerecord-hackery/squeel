require 'spec_helper'

module Squeel
  module Adapters
    module ActiveRecord
      describe RelationExtensions do

        describe 'finding by attribute' do

          it 'returns nil when passed an empty string' do
            Person.find_by_id('').should be_nil
          end

          it 'casts an empty string to the proper value' do
            queries = queries_for do
              Person.find_by_id('')
            end
            queries.should have(1).query
            queries.first.should match /"people"."id" = 0/
          end

        end

        describe '#build_arel' do

          it 'joins associations' do
            relation = Person.joins({
              :children => {
                :children => {
                  :parent => :parent
                }
              }
            })

            arel = relation.build_arel

            relation.join_dependency.join_associations.should have(4).items
            arel.to_sql.should match /INNER JOIN "people" "parents_people_2" ON "parents_people_2"."id" = "parents_people"."parent_id"/
          end

          it 'joins associations with custom join types' do
            relation = Person.joins({
              :children.outer => {
                :children => {
                  :parent => :parent.outer
                }
              }
            })

            arel = relation.build_arel

            relation.join_dependency.join_associations.should have(4).items
            arel.to_sql.should match /LEFT OUTER JOIN "people" "children_people"/
            arel.to_sql.should match /LEFT OUTER JOIN "people" "parents_people_2" ON "parents_people_2"."id" = "parents_people"."parent_id"/
          end

          it 'only joins an association once, even if two overlapping joins_values hashes are given' do
            relation = Person.joins({
              :children => {
                :children => {
                  :parent => :parent
                }
              }
            }).joins({
              :children => {
                :children => {
                  :children => :parent
                }
              }
            })

            arel = relation.build_arel
            relation.join_dependency.join_associations.should have(6).items
            arel.to_sql.should match /INNER JOIN "people" "parents_people_3" ON "parents_people_3"."id" = "children_people_3"."parent_id"/
          end

          it 'respects :uniq option on associations' do
            Article.first.uniq_commenters.length.should eq Article.first.uniq_commenters.count
          end

          it 'visits wheres with a PredicateVisitor, converting them to Arel nodes' do
            relation = Person.where(:name.matches => '%bob%')
            arel = relation.build_arel
            arel.to_sql.should match /"people"."name" LIKE '%bob%'/
          end

	  it 'handles multiple wheres using a keypath' do
	    relation = Person.joins{articles}.where{articles.title == 'Hello'}.
	                      where{articles.body == 'World'}
	    arel = relation.build_arel
	    arel.to_sql.should match /articles/
	  end

          it 'maps wheres inside a hash to their appropriate association table' do
            relation = Person.joins({
              :children => {
                :children => {
                  :parent => :parent
                }
              }
            }).where({
              :children => {
                :children => {
                  :parent => {
                    :parent => { :name => 'bob' }
                  }
                }
              }
            })

            arel = relation.build_arel

            arel.to_sql.should match /"parents_people_2"."name" = 'bob'/
          end

          it 'combines multiple conditions of the same type against the same column with AND' do
            relation = Person.where(:name.matches => '%bob%')
            relation = relation.where(:name.matches => '%joe%')
            arel = relation.build_arel
            arel.to_sql.should match /"people"."name" LIKE '%bob%' AND "people"."name" LIKE '%joe%'/
          end

          it 'handles ORs between predicates' do
            relation = Person.joins{articles}.where{(name =~ 'Joe%') | (articles.title =~ 'Hello%')}
            arel = relation.build_arel
            arel.to_sql.should match /OR/
          end

          it 'maintains groupings as given' do
            relation = Person.where(dsl{(name == 'Ernie') | ((name =~ 'Bob%') & (name =~ '%by'))})
            arel = relation.build_arel
            arel.to_sql.should match /"people"."name" = 'Ernie' OR \("people"."name" LIKE 'Bob%' AND "people"."name" LIKE '%by'\)/
          end

          it 'maps havings inside a hash to their appropriate association table' do
            relation = Person.joins({
              :children => {
                :children => {
                  :parent => :parent
                }
              }
            }).having({
              :children => {
                :children => {
                  :parent => {
                    :parent => {:name => 'joe'}
                  }
                }
              }
            })

            arel = relation.build_arel

            arel.to_sql.should match /HAVING "parents_people_2"."name" = 'joe'/
          end

          it 'maps orders inside a hash to their appropriate association table' do
            unless activerecord_version_at_least '4.0.0'
              relation = Person.joins({
                :children => {
                  :children => {
                    :parent => :parent
                  }
                }
              }).order({
                :children => {
                  :children => {
                    :parent => {
                      :parent => :id.asc
                    }
                  }
                }
              })

              arel = relation.build_arel

              arel.to_sql.should match /ORDER BY "parents_people_2"."id" ASC/
            else
              pending 'Unsupported in ActiveRecord 4.0.0+'
            end
          end

          it 'does not inadvertently convert KeyPaths to booleans when uniqing where_values' do
            100.times do # Doesn't happen reliably because of #hash behavior
              persons = Person.joins{[outgoing_messages.outer, incoming_messages.outer]}
              persons = persons.where { (outgoing_messages.author_id.not_eq 7) & (incoming_messages.author_id.not_eq 7) }
              persons = persons.where{(outgoing_messages.recipient_id.not_eq 7) & (incoming_messages.recipient_id.not_eq 7)}
              expect { persons.to_sql }.not_to raise_error TypeError
            end
          end

          it 'reverses order of Arel::Attributes when #last is called' do
            sorted_people = Person.all.to_a.sort {|a, b| a.name.downcase <=> b.name.downcase}

            Person.order{name}.last.should eq sorted_people.last
          end

          it 'removed duplicate order values' do
            ordered = Person.order{name.asc}.order{name.asc}
            ordered.to_sql.scan('name').should have(1).item
          end

        end

        describe '#to_sql' do
          it 'casts a non-acceptable value for a Function key properly in a hash' do
            relation = Person.joins(:children).where(:children => {:coalesce.func(:name, 'Mr. No-name') => 'Ernie'})
            relation.to_sql.should match /'Ernie'/
          end

          it 'casts a non-acceptable value for a Predicate containing a Function expr properly' do
            relation = Person.joins(:children).where(:children => {:coalesce.func(:name, 'Mr. No-name').eq => 'Ernie'})
            relation.to_sql.should match /'Ernie'/
          end

          it 'casts a non-acceptable value for a KeyPath with a Function endpoint properly' do
            relation = Person.joins(:children).where{{children.coalesce(:name, 'Mr. No-name') => 'Ernie'}}
            relation.to_sql.should match /'Ernie'/
          end

          it 'casts a non-acceptable value for a KeyPath with a Predicate endpoint containing a Function expr properly' do
            relation = Person.joins(:children).where{{children.coalesce(:name, 'Mr. No-name').eq => 'Ernie'}}
            relation.to_sql.should match /'Ernie'/
          end

          it 'casts a non-acceptable value for a Function with a Predicate endpoint containing a Function expr properly' do
            relation = Person.joins(:children).where{children.coalesce(:name, 'Mr. No-name') == 'Ernie'}
            relation.to_sql.should match /'Ernie'/
          end
        end

        describe '#includes' do

          it 'builds options with a block' do
            standard = Person.includes(:children => :children).where(:children => {:children => {:name => 'bob'}})
            block = Person.includes{{children => children}}.where(:children => {:children => {:name => 'bob'}})
            block.debug_sql.should eq standard.debug_sql
          end

          it 'eager loads multiple top-level associations with a block' do
            standard = Person.includes(:children, :articles, :comments).where(:children => {:name => 'bob'})
            block = Person.includes{[children, articles, comments]}.where(:children => {:name => 'bob'})
            block.debug_sql.should eq standard.debug_sql
          end

          it 'eager loads belongs_to associations' do
            queries = queries_for do
              Article.includes(:person).
                      where{person.name == 'Ernie'}.to_a
            end
            queries.should have(1).item
            queries.first.should match /LEFT OUTER JOIN "people"/
            queries.first.should match /"people"."name" = 'Ernie'/
          end

          it 'eager loads belongs_to associations on models with default_scopes' do
            queries = queries_for do
              PersonNamedBill.includes(:parent).
                              where{parent.name == 'Ernie'}.to_a
            end
            queries.should have(1).item
            queries.first.should match /LEFT OUTER JOIN "people"/
            queries.first.should match /"people"."name" = 'Bill'/
            queries.first.should match /"parents_people"."name" = 'Ernie'/
          end

          it 'eager loads polymorphic belongs_to associations' do
            relation = Note.includes{notable(Article)}.where{{notable(Article) => {title => 'hey'}}}
            relation.debug_sql.should match /"notes"."notable_type" = 'Article'/
          end

          it 'eager loads multiple polymorphic belongs_to associations' do
            relation = Note.includes{[notable(Article), notable(Person)]}.
                            where{{notable(Article) => {title => 'hey'}}}.
                            where{{notable(Person) => {name => 'joe'}}}
            relation.debug_sql.should match /"notes"."notable_type" = 'Article'/
            relation.debug_sql.should match /"notes"."notable_type" = 'Person'/
          end

          it "only includes once, even if two join types are used" do
            relation = Person.includes(:articles.inner, :articles.outer).where(:articles => {:title => 'hey'})
            relation.debug_sql.scan("JOIN").size.should eq 1
          end

          it 'includes a keypath' do
            relation = Note.includes{notable(Article).person.children}.where{notable(Article).person.children.name == 'Ernie'}
            relation.debug_sql.should match /SELECT "notes".* FROM "notes" LEFT OUTER JOIN "articles" ON "articles"."id" = "notes"."notable_id" AND "notes"."notable_type" = 'Article' LEFT OUTER JOIN "people" ON "people"."id" = "articles"."person_id" LEFT OUTER JOIN "people" "children_people" ON "children_people"."parent_id" = "people"."id"/
          end

        end

        describe '#preload' do

          it 'builds options with a block' do
            relation = Person.preload{children}
            queries_for {relation.to_a}.should have(2).items
            queries_for {relation.first.children}.should have(0).items
          end

          it 'builds options with a keypath' do
            relation = Person.preload{articles.comments}
            queries_for {relation.to_a}.should have(3).items
            queries_for {relation.first.articles.first.comments}.should have(0).items
          end

          it 'builds options with a hash' do
            relation = Person.preload{{
              articles => {
                comments => person
              }
            }}

            queries_for {relation.to_a}.should have(4).items

            queries_for {
              relation.first.articles
              relation.first.articles.first.comments
              relation.first.articles.first.comments.first.person
            }.should have(0).items
          end

        end

        describe '#eager_load' do

          it 'builds options with a block' do
            standard = Person.eager_load(:children => :children)
            block = Person.eager_load{{children => children}}
            block.debug_sql.should eq standard.debug_sql
            queries_for {block.to_a}.should have(1).item
            queries_for {block.first.children}.should have(0).items
          end

          it 'eager loads multiple top-level associations with a block' do
            standard = Person.eager_load(:children, :articles, :comments)
            block = Person.eager_load{[children, articles, comments]}
            block.debug_sql.should eq standard.debug_sql
          end

          it 'eager loads polymorphic belongs_to associations' do
            relation = Note.eager_load{notable(Article)}
            relation.debug_sql.should match /"notes"."notable_type" = 'Article'/
          end

          it 'eager loads multiple polymorphic belongs_to associations' do
            relation = Note.eager_load{[notable(Article), notable(Person)]}
            relation.debug_sql.should match /"notes"."notable_type" = 'Article'/
            relation.debug_sql.should match /"notes"."notable_type" = 'Person'/
          end

          it "only eager_load once, even if two join types are used" do
            relation = Person.eager_load(:articles.inner, :articles.outer)
            relation.debug_sql.scan("JOIN").size.should eq 1
          end

          it 'eager_load a keypath' do
            relation = Note.eager_load{notable(Article).person.children}
            relation.debug_sql.should match /SELECT "notes".* FROM "notes" LEFT OUTER JOIN "articles" ON "articles"."id" = "notes"."notable_id" AND "notes"."notable_type" = 'Article' LEFT OUTER JOIN "people" ON "people"."id" = "articles"."person_id" LEFT OUTER JOIN "people" "children_people" ON "children_people"."parent_id" = "people"."id"/
          end

        end

        describe '#select' do

          it 'accepts options from a block' do
            standard = Person.select(:id)
            block = Person.select {id}
            block.to_sql.should eq standard.to_sql
          end

          it 'falls back to Array#select with a block that has an arity > 0' do
            people = Person.select{|p| p.id == 1}
            people.should have(1).person
            people.first.id.should eq 1
          end

          it 'falls back to Array#select with Symbol#to_proc block' do
            if Squeel.sane_arity?
              people = Person.select(&:odd?)
              people.map(&:id)[0..3].should eq [1, 3, 5, 7]
            else
              pending 'This version of Ruby has insane Proc#arity behavior.'
            end
          end

          it 'behaves as normal with standard parameters' do
            people = Person.select(:id)
            people.should have(332).people
            expect { people.first.name }.to raise_error ActiveModel::MissingAttributeError
          end

          it 'works with multiple fields in select' do
            Article.select("title, body").count.should eq 51
          end

          it 'allows a function in the select values via Symbol#func' do
            relation = Person.select(:max.func(:id).as('max_id'))
            relation.first.max_id.should eq 332
          end

          it 'allows a function in the select values via block' do
            relation = Person.select{max(id).as(max_id)}
            relation.first.max_id.should eq 332
          end

          it 'allows an operation in the select values via block' do
            relation = Person.select{[id, (id + 1).as('id_plus_one')]}.where('id_plus_one = 2')
            relation.first.id.should eq 1
          end

          it 'allows custom operators in the select values via block' do
            relation = Person.select{name.op('||', '-diddly').as(flanderized_name)}
            relation.first.flanderized_name.should eq Person.first.name + '-diddly'
          end

          it 'allows a subquery in the select values' do
            subquery = Article.where(:person_id => 1).select(:id).order{id.desc}.limit(1)
            relation = Person.where(:id => 1).select{[id, name, subquery.as('last_article_id')]}
            aric = relation.first
            aric.last_article_id.should eq Article.where(:person_id => 1).last.id
          end

        end

        describe '#count' do

          it 'works with non-strings in select' do
            Article.select{distinct(title)}.count.should eq 51
          end

          it 'works with non-strings in wheres' do
            first_name = Person.first.name
            Person.where{name.op('=', first_name)}.count.should eq 1
          end

          it 'works with non-strings in group' do
            if activerecord_version_at_least '3.2.7'
              counts = Person.group{name.op('||', '-diddly')}.count
              counts.should eq Person.group("name || '-diddly'").count
            else
              pending 'Unsupported in Active Record < 3.2.7'
            end
          end
        end

        describe '#group' do

          it 'builds options with a block' do
            standard = Person.group(:name)
            block = Person.group{name}
            block.to_sql.should eq standard.to_sql
          end

        end

        describe '#where' do

          it 'builds options with a block' do
            standard = Person.where(:name => 'bob')
            block = Person.where{{name => 'bob'}}
            block.to_sql.should eq standard.to_sql
          end

          it 'builds compound conditions with a block' do
            block = Person.where{(name == 'bob') & (salary == 100000)}
            block.to_sql.should match /"people"."name" = 'bob'/
            block.to_sql.should match /AND/
            block.to_sql.should match /"people"."salary" = 100000/
          end

          it 'allows mixing hash and operator syntax inside a block' do
            block = Person.joins(:comments).
                           where{(name == 'bob') & {comments => (body == 'First post!')}}
            block.to_sql.should match /"people"."name" = 'bob'/
            block.to_sql.should match /AND/
            block.to_sql.should match /"comments"."body" = 'First post!'/
          end

          it 'allows a condition on a function via block' do
            relation = Person.where{coalesce(nil,id) == 5}
            relation.first.id.should eq 5
          end

          it 'allows a condition on an operation via block' do
            relation = Person.where{(id + 1) == 2}
            relation.first.id.should eq 1
          end

          it 'maps conditions onto their proper table with multiple polymorphic joins' do
            relation = Note.joins{[notable(Article).outer, notable(Person).outer]}
            people_notes = relation.where{notable(Person).salary > 30000}
            article_notes = relation.where{notable(Article).title =~ '%'}
            people_and_article_notes = relation.where{(notable(Person).salary > 30000) | (notable(Article).title =~ '%')}
            people_notes.should have(10).items
            article_notes.should have(30).items
            people_and_article_notes.should have(40).items
          end

          it 'allows a subquery on the value side of a predicate' do
            names = [Person.first.name, Person.last.name]
            old_and_busted = Person.where(:name => names)
            new_hotness = Person.where{name.in(Person.select{name}.where{name.in(names)})}
            new_hotness.should have(2).items
            old_and_busted.to_a.should eq new_hotness.to_a
          end

          it 'is backwards-compatible with "where.not"' do
            if activerecord_version_at_least '4.0.0'
              name = Person.first.name
              result = Person.where.not(:name => name)
              result.should_not include Person.first
            else
              pending 'Not required pre-4.0'
            end
          end

          it 'allows equality conditions against a belongs_to with an AR::Base value' do
            first_person = Person.first
            relation = Article.where { person.eq first_person }
            relation.to_sql.should match /"articles"."person_id" = #{first_person.id}/
          end

          it 'allows equality conditions against a polymorphic belongs_to with an AR::Base value' do
            first_person = Person.first
            relation = Note.where { notable.eq first_person }
            relation.to_sql.should match /"notes"."notable_id" = #{first_person.id} AND "notes"."notable_type" = 'Person'/
          end

          it 'allows inequality conditions against a belongs_to with an AR::Base value' do
            first_person = Person.first
            relation = Article.where { person.not_eq first_person }
            relation.to_sql.should match /"articles"."person_id" != #{first_person.id}/
          end

          it 'allows inequality conditions against a polymorphic belongs_to with an AR::Base value' do
            first_person = Person.first
            relation = Note.where { notable.not_eq first_person }
            relation.to_sql.should match /\("notes"."notable_id" != #{first_person.id} OR "notes"."notable_type" != 'Person'\)/
          end

          it 'allows hash equality conditions against a belongs_to with an AR::Base value' do
            first_person = Person.first
            relation = Article.where(:person => first_person)
            relation.to_sql.should match /"articles"."person_id" = #{first_person.id}/
          end

          it 'allows hash equality conditions against a polymorphic belongs_to with an AR::Base value' do
            first_person = Person.first
            relation = Note.where(:notable => first_person)
            relation.to_sql.should match /"notes"."notable_id" = #{first_person.id} AND "notes"."notable_type" = 'Person'/
          end

        end

        describe '#joins' do

          it 'builds options with a block' do
            standard = Person.joins(:children => :children)
            block = Person.joins{{children => children}}
            block.to_sql.should eq standard.to_sql
          end

          it 'accepts multiple top-level associations with a block' do
            standard = Person.joins(:children, :articles, :comments)
            block = Person.joins{[children, articles, comments]}
            block.to_sql.should eq standard.to_sql
          end

          it 'joins has_many :through associations' do
            relation = Person.joins(:authored_article_comments)
            relation.first.authored_article_comments.first.should eq Comment.first
          end

          it 'creates a unique join when joining a table used in a has_many :through association' do
            Person.first.authored_article_comments.joins(:article).first.should eq Comment.first
          end

          it 'joins polymorphic belongs_to associations' do
            relation = Note.joins{notable(Article)}
            relation.to_sql.should match /"notes"."notable_type" = 'Article'/
          end

          it 'joins multiple polymorphic belongs_to associations' do
            relation = Note.joins{[notable(Article), notable(Person)]}
            relation.to_sql.should match /"notes"."notable_type" = 'Article'/
            relation.to_sql.should match /"notes"."notable_type" = 'Person'/
          end

          it "only joins once, even if two join types are used" do
            relation = Person.joins(:articles.inner, :articles.outer)
            relation.to_sql.scan("JOIN").size.should eq 1
          end

          it 'joins a keypath' do
            relation = Note.joins{notable(Article).person.children}
            relation.to_sql.should match /SELECT "notes".* FROM "notes" INNER JOIN "articles" ON "articles"."id" = "notes"."notable_id" AND "notes"."notable_type" = 'Article' INNER JOIN "people" ON "people"."id" = "articles"."person_id" INNER JOIN "people" "children_people" ON "children_people"."parent_id" = "people"."id"/
          end

        end

        describe '#having' do

          it 'builds options with a block' do
            standard = Person.having(:name => 'bob')
            block = Person.having{{name => 'bob'}}
            block.to_sql.should eq standard.to_sql
          end

          it 'allows complex conditions on aggregate columns' do
            relation = Person.group(:parent_id).having{salary == max(salary)}
            relation.first.name.should eq Person.last.name
          end

          it 'allows a condition on a function via block' do
            relation = Person.group(:id).having{coalesce(nil,id) == 5}
            relation.first.id.should eq 5
          end

          it 'allows a condition on an operation via block' do
            relation = Person.group(:id).having{(id + 1) == 2}
            relation.first.id.should eq 1
          end

        end

        describe '#order' do

          it 'builds options with a block' do
            block = Person.order{name}
            block.to_sql.should match /ORDER BY "people"\."name"/
          end

          it 'allows AR 4.0-style hash options' do
            if activerecord_version_at_least '4.0.0'
              block = Person.order(:name => :desc)
              block.to_sql.should match /ORDER BY "people"\."name" DESC/
            else
              pending 'Not required in AR versions < 4.0.0'
            end
          end

          it 'allows ordering by an attributes of a joined table' do
            relation = Article.joins(:person).order { person.id.asc }
            relation.to_sql.should match /ORDER BY "people"\."id" ASC/
          end

        end

        describe '#reorder' do
          before do
            @standard = Person.order(:name)
          end

          it 'builds options with a block' do
            block = @standard.reorder{id}
            block.to_sql.should_not eq @standard.to_sql
            block.to_sql.should match /ORDER BY "people"."id"/
          end

          it 'drops order by clause when passed nil' do
            block = @standard.reorder(nil)
            sql = block.to_sql
            sql.should_not match /ORDER BY/
          end

          it 'drops order by clause when passed nil if reversed' do
            block = @standard.reverse_order.reorder(nil)
            sql = block.to_sql
            sql.should_not match /ORDER BY/
          end

        end

        describe '#from' do
          it 'creates froms with a block' do
            expected = /SELECT "sub"."name" AS aliased_name FROM \(SELECT "people"."name" FROM "people"\s*\) sub/
            block = Person.from{Person.select{name}.as('sub')}.
              select{sub.name.as('aliased_name')}
            sql = block.to_sql
            sql.should match expected
          end

          it 'creates froms from literals' do
            expected = /SELECT "people".* FROM sub/
            relation = Person.from('sub')
            sql = relation.to_sql
            sql.should match expected
          end

          it 'creates froms from relations' do
            if activerecord_version_at_least '4.0.0'
              expected = "SELECT \"people\".* FROM (SELECT \"people\".* FROM \"people\") alias"
              relation = Person.from(Person.all, 'alias')
              sql = relation.to_sql
              sql.should == expected
            else
              pending 'Unsupported before ActiveRecord 4.0'
            end
          end
        end

        describe '#build_where' do

          it 'sanitizes SQL as usual with strings' do
            wheres = Person.where('name like ?', '%bob%').where_values
            wheres.should eq ["name like '%bob%'"]
          end

          it 'sanitizes SQL as usual with strings and hash substitution' do
            wheres = Person.where('name like :name', :name => '%bob%').where_values
            wheres.should eq ["name like '%bob%'"]
          end

          it 'sanitizes SQL as usual with arrays' do
            wheres = Person.where(['name like ?', '%bob%']).where_values
            wheres.should eq ["name like '%bob%'"]
          end

          it 'adds hash where values without converting to Arel predicates' do
            wheres = Person.where({:name => 'bob'}).where_values
            wheres.should eq [{:name => 'bob'}]
          end

        end

        describe '#debug_sql' do

          it 'returns the query that would be run against the database, even if eager loading' do
            relation = Person.includes(:comments, :articles).
              where(:comments => {:body => 'First post!'}).
              where(:articles => {:title => 'Hello, world!'})
            relation.debug_sql.should_not eq relation.to_sql
            relation.debug_sql.should match /SELECT "people"."id" AS t0_r0/
          end

        end

        describe '#where_values_hash' do

          it 'creates new records with equality predicates from wheres' do
            @person = Person.where(:name => 'bob', :parent_id => 3).new
            @person.parent_id.should eq 3
            @person.name.should eq 'bob'
          end

          it 'creates new records with equality predicates from has_many associations' do
            if activerecord_version_at_least '3.1.0'
              person = Person.first
              article = person.articles_with_condition.new
              article.person.should eq person
              article.title.should eq 'Condition'
            else
              pending 'Unsupported on Active Record < 3.1'
            end
          end

          it 'creates new records with equality predicates from has_many :through associations' do
            pending "When Active Record supports this, we'll want to, too"
            person = Person.first
            comment = person.article_comments_with_first_post.new
            comment.body.should eq 'first post'
          end

          it "maintains activerecord default scope functionality" do
            PersonNamedBill.new.name.should eq 'Bill'
          end

          it 'uses the last supplied equality predicate in where_values when creating new records' do
            @person = Person.where(:name => 'bob', :parent_id => 3).where(:name => 'joe').new
            @person.parent_id.should eq 3
            @person.name.should eq 'joe'
          end

          it 'creates through a join model' do
            Article.transaction do
              article = Article.first
              person = article.commenters.create(:name => 'Ernie Miller')
              person.should be_persisted
              person.comments.should have(1).comment
              person.comments.first.article.should eq article
              raise ::ActiveRecord::Rollback
            end
          end

        end

        describe '#as' do

          it 'aliases the relation in an As node' do
            relation = Person.where{name == 'ernie'}
            node = relation.as('ernie')
            node.should be_a Squeel::Nodes::As
            node.expr.should eq relation
            node.alias.should be_a Arel::Nodes::SqlLiteral
            node.alias.should eq 'ernie'
          end

        end

        describe '#merge' do

          it 'merges relations with the same base' do
            relation = Person.where{name == 'bob'}.merge(Person.where{salary == 100000})
            sql = relation.to_sql
            sql.should match /"people"."name" = 'bob'/
            sql.should match /"people"."salary" = 100000/
          end

          it 'merges relations with a different base' do
            relation = Person.where{name == 'bob'}.joins(:articles).merge(Article.where{title == 'Hello world!'})
            sql = relation.to_sql
            sql.should match /INNER JOIN "articles" ON "articles"."person_id" = "people"."id"/
            sql.should match /"people"."name" = 'bob'/
            sql.should match /"articles"."title" = 'Hello world!'/
          end

          it 'does not break hm:t with conditions' do
            relation = Person.first.condition_article_comments
            sql = relation.scoped.to_sql
            sql.should match /"articles"."title" = 'Condition'/
          end

          it 'uses the last condition in the case of a conflicting where' do
            relation = Person.where{name == 'Ernie'}.merge(
              Person.where{name == 'Bert'}
            )
            sql = relation.to_sql
            sql.should_not match /Ernie/
            sql.should match /Bert/
          end

          it 'uses the given equality condition in the case of a conflicting where from a default scope' do
            if activerecord_version_at_least '3.1'
              relation = PersonNamedBill.where{name == 'Ernie'}
              sql = relation.to_sql
              sql.should_not match /Bill/
              sql.should match /Ernie/
            else
              pending 'Unsupported in Active Record < 3.1'
            end
          end

          it 'allows scopes to join/query a table through two different associations and uses the correct alias' do
            relation = Person.with_article_title('hi').
                              with_article_condition_title('yo')
            sql = relation.to_sql
            sql.should match /"articles"."title" = 'hi'/
            sql.should match /"articles_with_conditions_people"."title" = 'yo'/
          end

          it "doesn't ruin everything when a scope returns nil" do
            relation = Person.nil_scope
            relation.should eq Person.scoped
          end

          it "doesn't ruin everything when a group exists" do
            relation = Person.scoped.merge(Person.group{name})
            count_hash = {}
            expect { count_hash = relation.count }.should_not raise_error
            count_hash.size.should eq Person.scoped.size
            count_hash.values.all? {|v| v == 1}.should be_true
            count_hash.keys.should =~ Person.select{name}.map(&:name)
          end

          it "doesn't merge the default scope more than once" do
            relation = PersonNamedBill.scoped.highly_compensated.ending_with_ill
            sql = relation.to_sql
            sql.scan(/"people"."name" = 'Bill'/).should have(1).item
            sql.scan(/"people"."name" LIKE '%ill'/).should have(1).item
            sql.scan(/"people"."salary" > 200000/).should have(1).item
            sql.scan(/"people"."id"/).should have(1).item
          end

          it "doesn't hijack the table name when merging a relation with different base and default_scope" do
            relation = Article.joins(:person).merge(PersonNamedBill.scoped)
            sql = relation.to_sql
            sql.scan(/"people"."name" = 'Bill'/).should have(1).item
          end

          it 'merges scopes that contain functions' do
            relation = PersonNamedBill.scoped.with_salary_equal_to(100)
            sql = relation.to_sql
            sql.should match /abs\("people"."salary"\) = 100/
          end

          it 'uses last equality when merging two scopes with identical function equalities' do
            relation = PersonNamedBill.scoped.with_salary_equal_to(100).
                                              with_salary_equal_to(200)
            sql = relation.to_sql
            sql.should_not match /abs\("people"."salary"\) = 100/
            sql.should match /abs\("people"."salary"\) = 200/
          end

        end

        describe '#to_a' do

          it 'eager-loads associations with dependent conditions' do
            relation = Person.includes(:comments, :articles).
              where{{comments => {body => 'First post!'}}}
            relation.size.should be 1
            person = relation.first
            person.should eq Person.last
            person.comments.loaded?.should be true
          end

          it 'includes a belongs_to association even if the child model has no primary key' do
            relation = UnidentifiedObject.where{person_id < 120}.includes(:person)
            queries = queries_for do
              vals = relation.to_a
              vals.should have(8).items
            end

            queries.should have(2).queries

            matched_ids = queries.last.match(/IN \(([^)]*)/).captures.first
            matched_ids = matched_ids.split(/,\s*/).map(&:to_i)
            matched_ids.should =~ [1, 34, 67, 100]
          end

        end

      end
    end
  end
end
