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
            if activerecord_version_at_least('3.1.0')
              queries.should have(1).query
            else
              puts 'skips count of queries expectation'
            end

            if activerecord_version_at_least('4.2.0')
              if PG_ENV
                queries.last.should match /#{Q}people#{Q}.#{Q}id#{Q} = \$1/
              else
                queries.last.should match /#{Q}people#{Q}.#{Q}id#{Q} = ?/
              end
            else
              queries.last.should match /#{Q}people#{Q}.#{Q}id#{Q} = 0/
            end
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

            if activerecord_version_at_least('4.1.0')
              relation.join_dependency.join_constraints([]).should have(4).items
            else
              relation.join_dependency.join_associations.should have(4).items
            end
            arel.to_sql.should match /INNER JOIN #{Q}people#{Q} #{Q}parents_people_2#{Q} ON #{Q}parents_people_2#{Q}.#{Q}id#{Q} = #{Q}parents_people#{Q}.#{Q}parent_id#{Q}/
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

            if activerecord_version_at_least('4.1.0')
              relation.join_dependency.join_constraints([]).should have(4).items
            else
              relation.join_dependency.join_associations.should have(4).items
            end
            arel.to_sql.should match /LEFT OUTER JOIN #{Q}people#{Q} #{Q}children_people#{Q}/
            arel.to_sql.should match /LEFT OUTER JOIN #{Q}people#{Q} #{Q}parents_people_2#{Q} ON #{Q}parents_people_2#{Q}.#{Q}id#{Q} = #{Q}parents_people#{Q}.#{Q}parent_id#{Q}/
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
            if activerecord_version_at_least('4.1.0')
              relation.join_dependency.join_constraints([]).should have(6).items
            else
              relation.join_dependency.join_associations.should have(6).items
            end
            arel.to_sql.should match /INNER JOIN #{Q}people#{Q} #{Q}parents_people_3#{Q} ON #{Q}parents_people_3#{Q}.#{Q}id#{Q} = #{Q}children_people_3#{Q}.#{Q}parent_id#{Q}/
          end

          it 'respects :uniq option on associations' do
            Article.first.uniq_commenters.length.should eq Article.first.uniq_commenters.count
          end

          it 'visits wheres with a PredicateVisitor, converting them to Arel nodes' do
            relation = Person.where(:name.matches => '%bob%')
            arel = relation.build_arel
            arel.to_sql.should match /#{Q}people#{Q}.#{Q}name#{Q} [I]*LIKE '%bob%'/
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

            if activerecord_version_at_least('4.2.0')
              arel.to_sql.should match /#{Q}parents_people_2#{Q}.#{Q}name#{Q} = ?/
            else
              arel.to_sql.should match /#{Q}parents_people_2#{Q}.#{Q}name#{Q} = 'bob'/
            end
          end

          it 'combines multiple conditions of the same type against the same column with AND' do
            relation = Person.where(:name.matches => '%bob%')
            relation = relation.where(:name.matches => '%joe%')
            arel = relation.build_arel
            arel.to_sql.should match /#{Q}people#{Q}.#{Q}name#{Q} [I]*LIKE '%bob%' AND #{Q}people#{Q}.#{Q}name#{Q} [I]*LIKE '%joe%'/
          end

          it 'handles ORs between predicates' do
            relation = Person.joins{articles}.where{(name =~ 'Joe%') | (articles.title =~ 'Hello%')}
            arel = relation.build_arel
            arel.to_sql.should match /OR/
          end

          it 'maintains groupings as given' do
            relation = Person.where(dsl{(name == 'Ernie') | ((name =~ 'Bob%') & (name =~ '%by'))})
            arel = relation.build_arel
            arel.to_sql.should match /#{Q}people#{Q}.#{Q}name#{Q} = 'Ernie' OR \(#{Q}people#{Q}.#{Q}name#{Q} [I]*LIKE 'Bob%' AND #{Q}people#{Q}.#{Q}name#{Q} [I]*LIKE '%by'\)/
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

            if activerecord_version_at_least('4.2.0')
              arel.to_sql.should match /HAVING #{Q}parents_people_2#{Q}.#{Q}name#{Q} = ?/
            else
              arel.to_sql.should match /HAVING #{Q}parents_people_2#{Q}.#{Q}name#{Q} = 'joe'/
            end
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
              arel.to_sql.should match /ORDER BY #{Q}parents_people_2#{Q}.#{Q}id#{Q} ASC/
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

          it 'returns the first item when #last is called after reversing the order' do
            sorted_people = Person.all.to_a.sort {|a, b| a.name.downcase <=> b.name.downcase}
            Person.order(name: :desc).first.should eq sorted_people.last
            Person.order(name: :desc).last.should eq sorted_people.first
            Person.reorder(name: :desc).first.should eq sorted_people.last
            Person.reorder(:name).reverse_order.last.should eq sorted_people.first
            Person.reorder(name: :desc).last.should eq sorted_people.first # this fails
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
              if activerecord_version_at_least('4.1.0')
                Article.includes(:person).references(:person).
                        where{person.name == 'Ernie'}.to_a
              else
                Article.includes(:person).
                        where{person.name == 'Ernie'}.to_a
              end
            end

            if activerecord_version_at_least('4.1.0')
              queries.should have(1).item
            else
              puts 'skips count of queries expectation.'
            end

            queries.last.should match /LEFT OUTER JOIN #{Q}people#{Q}/
            queries.last.should match /#{Q}people#{Q}.#{Q}name#{Q} = 'Ernie'/
          end

          it 'eager loads belongs_to associations on models with default_scopes' do
            queries = queries_for do
              if activerecord_version_at_least('4.1.0')
                PersonNamedBill.includes(:parent).references(:parent).
                                where{parent.name == 'Ernie'}.to_a
              else
                PersonNamedBill.includes(:parent).
                                where{parent.name == 'Ernie'}.to_a
              end

            end

            if activerecord_version_at_least('4.1.0')
              queries.should have(1).item
            else
              puts 'skips count of queries expectation.'
            end

            queries.last.should match /LEFT OUTER JOIN #{Q}people#{Q}/
            queries.last.should match /#{Q}people#{Q}.#{Q}name#{Q} = 'Bill'/
            queries.last.should match /#{Q}parents_people#{Q}.#{Q}name#{Q} = 'Ernie'/
          end

          it 'eager loads polymorphic belongs_to associations' do
            relation = Note.includes{notable(Article)}.where{{notable(Article) => {title => 'hey'}}}
            relation.debug_sql.should match /#{Q}notes#{Q}.#{Q}notable_type#{Q} = 'Article'/
          end

          it 'eager loads multiple polymorphic belongs_to associations' do
            relation = Note.includes{[notable(Article), notable(Person)]}.
                            where{{notable(Article) => {title => 'hey'}}}.
                            where{{notable(Person) => {name => 'joe'}}}
            relation.debug_sql.should match /#{Q}notes#{Q}.#{Q}notable_type#{Q} = 'Article'/
            relation.debug_sql.should match /#{Q}notes#{Q}.#{Q}notable_type#{Q} = 'Person'/
          end

          it 'only includes once, even if two join types are used' do
            relation = Person.includes(:articles.inner, :articles.outer).where(:articles => {:title => 'hey'})
            if activerecord_version_at_least('4.1.0')
              pending ":article != :article.inner != :article.outer, you shouldn't pass two same tables into includes again"
            else
              relation.debug_sql.scan("JOIN").size.should eq 1
            end
          end

          it 'includes a keypath' do
            if activerecord_version_at_least('4.1.0')
              relation = Note.includes{notable(Article).person.children}.references(:all).where{notable(Article).person.children.name == 'Ernie'}
            else
              relation = Note.includes{notable(Article).person.children}.where{notable(Article).person.children.name == 'Ernie'}
            end
            relation.debug_sql.should match /SELECT #{Q}notes#{Q}.* FROM #{Q}notes#{Q} LEFT OUTER JOIN #{Q}articles#{Q} ON #{Q}articles#{Q}.#{Q}id#{Q} = #{Q}notes#{Q}.#{Q}notable_id#{Q} AND #{Q}notes#{Q}.#{Q}notable_type#{Q} = 'Article' LEFT OUTER JOIN #{Q}people#{Q} ON #{Q}people#{Q}.#{Q}id#{Q} = #{Q}articles#{Q}.#{Q}person_id#{Q} LEFT OUTER JOIN #{Q}people#{Q} #{Q}children_people#{Q} ON #{Q}children_people#{Q}.#{Q}parent_id#{Q} = #{Q}people#{Q}.#{Q}id#{Q} WHERE #{Q}children_people#{Q}.#{Q}name#{Q} = 'Ernie'/
          end

          it 'eager loads has_and_belongs_to_many' do
            expect { Article.includes{tags}.to_a }.should_not raise_error
            expect { Person.includes{authored_article_comments}.to_a }.should_not raise_error
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
            if activerecord_version_at_least('3.2.0')
              queries_for {block.to_a}.should have(1).item
              queries_for {block.first.children}.should have(0).items
            else
              puts 'skips count of queries expectation.'
            end
          end

          it 'eager loads multiple top-level associations with a block' do
            standard = Person.eager_load(:children, :articles, :comments)
            block = Person.eager_load{[children, articles, comments]}
            block.debug_sql.should eq standard.debug_sql
          end

          it 'eager loads polymorphic belongs_to associations' do
            relation = Note.eager_load{notable(Article)}
            relation.debug_sql.should match /#{Q}notes#{Q}.#{Q}notable_type#{Q} = 'Article'/
          end

          it 'eager loads multiple polymorphic belongs_to associations' do
            relation = Note.eager_load{[notable(Article), notable(Person)]}
            relation.debug_sql.should match /#{Q}notes#{Q}.#{Q}notable_type#{Q} = 'Article'/
            relation.debug_sql.should match /#{Q}notes#{Q}.#{Q}notable_type#{Q} = 'Person'/
          end

          it "only eager_load once, even if two join types are used" do
            relation = Person.eager_load(:articles.inner, :articles.outer)
            if activerecord_version_at_least('4.1.0')
              pending ":article != :article.inner != :article.outer, you shouldn't pass two same tables into eager_load again"
            else
              relation.debug_sql.scan("JOIN").size.should eq 1
            end
          end

          it 'eager_load a keypath' do
            relation = Note.eager_load{notable(Article).person.children}
            relation.debug_sql.should match /SELECT #{Q}notes#{Q}.* FROM #{Q}notes#{Q} LEFT OUTER JOIN #{Q}articles#{Q} ON #{Q}articles#{Q}.#{Q}id#{Q} = #{Q}notes#{Q}.#{Q}notable_id#{Q} AND #{Q}notes#{Q}.#{Q}notable_type#{Q} = 'Article' LEFT OUTER JOIN #{Q}people#{Q} ON #{Q}people#{Q}.#{Q}id#{Q} = #{Q}articles#{Q}.#{Q}person_id#{Q} LEFT OUTER JOIN #{Q}people#{Q} #{Q}children_people#{Q} ON #{Q}children_people#{Q}.#{Q}parent_id#{Q} = #{Q}people#{Q}.#{Q}id#{Q}/
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
            people.should have(10).people
            if ::ActiveRecord::VERSION::MAJOR == 3 && ::ActiveRecord::VERSION::MINOR == 0 && RUBY_VERSION >= '2.0.0'
              people.first.name.should be_nil
            else
              expect { people.first.name }.to raise_error ActiveModel::MissingAttributeError
            end
          end

          it 'works with multiple fields in select' do
            Article.select("title, body").size.should eq 31
          end

          it 'allows a function in the select values via Symbol#func' do
            relation = Person.select(:max.func(:id).as('max_id')).order('max_id')
            relation.first.max_id.to_i.should eq 10
          end

          it 'allows a function in the select values via block' do
            relation = Person.select{max(id).as(max_id)}.order('max_id')
            relation.first.max_id.to_i.should eq 10
          end

          it 'allows an operation in the select values via block' do
            relation =
              if SQLITE_ENV
                Person.select{[id, (id + 1).as('id_plus_one')]}.where('id_plus_one = 2')
              else
                Person.select{[id, (id + 1).as('id_plus_one')]}.where{(id + 1) == 2}
              end
              relation.first.id.should eq 1
          end

          it 'allows custom operators in the select values via block' do
            if MYSQL_ENV
              pending "MySQL doesn't support concating string with ||."
            else
              relation = Person.select{name.op('||', '-diddly').as(flanderized_name)}
              relation.first.flanderized_name.should eq Person.first.name + '-diddly'
            end
          end

          it 'allows a subquery in the select values' do
            subquery = Article.where(:person_id => 1).select(:id).order{id.desc}.limit(1)
            relation = Person.where(:id => 1).select{[id, name, subquery.as('last_article_id')]}
            aric = relation.first
            aric.last_article_id.to_i.should eq Article.where(:person_id => 1).last.id
          end

        end

        describe '#count' do

          it 'works with non-strings in select' do
            Article.select{distinct(title)}.count.should eq 31
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

          it 'returns size correctly using group' do
            if activerecord_version_at_least('3.2.0')
              relation = Article.joins{person}.group{person.id}
              relation.size.should have(10).items
              relation.size[Person.first.id].should == 3
            end

            relation = Article.joins{person}.group{"people.id"}
            relation.size.should have(10).items
            relation.size[Person.first.id].should == 3

            relation = Article.joins{person}.group("people.id")
            relation.size.should have(10).items
            relation.size[Person.first.id].should == 3

            relation = Article.group{person_id}
            relation.size.should have(11).items
            relation.size[Person.first.id].should == 3

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
            block.to_sql.should match /#{Q}people#{Q}.#{Q}name#{Q} = 'bob'/
            block.to_sql.should match /AND/
            block.to_sql.should match /#{Q}people#{Q}.#{Q}salary#{Q} = 100000/
          end

          it 'allows mixing hash and operator syntax inside a block' do
            block = Person.joins(:comments).
                           where{(name == 'bob') & {comments => (body == 'First post!')}}
            block.to_sql.should match /#{Q}people#{Q}.#{Q}name#{Q} = 'bob'/
            block.to_sql.should match /AND/
            block.to_sql.should match /#{Q}comments#{Q}.#{Q}body#{Q} = 'First post!'/
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

          it 'maps conditions onto their proper table with a polymorphic belongs_to join followed by a polymorphic has_many join' do
            relation = Note.joins{notable(Article).notes}.
              where{notable(Article).notes.note.eq('zomg')}
            relation.to_sql.should match /#{Q}notes_articles#{Q}\.#{Q}note#{Q} = 'zomg'/
          end

          it 'allows a subquery on the value side of a predicate' do
            names = [Person.first.name, Person.last.name]
            old_and_busted = Person.where(:name => names)
            new_hotness = Person.where{name.in(Person.select{name}.where{name.in(names)})}
            new_hotness.should have(2).items
            old_and_busted.to_a.should eq new_hotness.to_a
          end

          it 'allows a subquery from an association in a hash' do
            scope = Person.first.articles
            articles = scope.where(:id => scope)
            articles.should have(3).articles

            articles = Tag.all.second.articles.where(:id => scope)
            articles.should have(1).articles
          end

          it 'allows a subquery from an association in a Squeel node' do
            scope = Person.first.articles
            articles = scope.where{id.in scope}
            articles.should have(3).articles
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
            relation.to_sql.should match /#{Q}articles#{Q}.#{Q}person_id#{Q} = #{first_person.id}/
          end

          it 'allows equality conditions against a polymorphic belongs_to with an AR::Base value' do
            first_person = Person.first
            relation = Note.where { notable.eq first_person }
            relation.to_sql.should match /#{Q}notes#{Q}.#{Q}notable_id#{Q} = #{first_person.id} AND #{Q}notes#{Q}.#{Q}notable_type#{Q} = 'Person'/
          end

          it 'allows inequality conditions against a belongs_to with an AR::Base value' do
            first_person = Person.first
            relation = Article.where { person.not_eq first_person }
            relation.to_sql.should match /#{Q}articles#{Q}.#{Q}person_id#{Q} != #{first_person.id}/
          end

          it 'allows inequality conditions against a polymorphic belongs_to with an AR::Base value' do
            first_person = Person.first
            relation = Note.where { notable.not_eq first_person }
            relation.to_sql.should match /\(#{Q}notes#{Q}.#{Q}notable_id#{Q} != #{first_person.id} OR #{Q}notes#{Q}.#{Q}notable_type#{Q} != 'Person'\)/
          end

          it 'allows hash equality conditions against a belongs_to with an AR::Base value' do
            first_person = Person.first
            relation = Article.where(:person => first_person)
            relation.to_sql.should match /#{Q}articles#{Q}.#{Q}person_id#{Q} = #{first_person.id}/
          end

          it 'allows hash equality conditions against a polymorphic belongs_to with an AR::Base value' do
            first_person = Person.first
            relation = Note.where(:notable => first_person)
            relation.to_sql.should match /#{Q}notes#{Q}.#{Q}notable_type#{Q} = 'Person'/
            relation.to_sql.should match /#{Q}notes#{Q}.#{Q}notable_id#{Q} = #{first_person.id}/
          end

          it 'keeps original AR hashes behavior' do
            relation = Person.joins(:articles).where(articles: { person_id: Person.first })
            relation.to_sql.should match /SELECT #{Q}people#{Q}.* FROM #{Q}people#{Q} INNER JOIN #{Q}articles#{Q} ON #{Q}articles#{Q}.#{Q}person_id#{Q} = #{Q}people#{Q}.#{Q}id#{Q} WHERE #{Q}articles#{Q}.#{Q}person_id#{Q} = 1/

            relation = Person.joins(:articles).where(articles: { person_id: Person.all.to_a })
            relation.to_sql.should match /SELECT #{Q}people#{Q}.\* FROM #{Q}people#{Q} INNER JOIN #{Q}articles#{Q} ON #{Q}articles#{Q}.#{Q}person_id#{Q} = #{Q}people#{Q}.#{Q}id#{Q} WHERE #{Q}articles#{Q}.#{Q}person_id#{Q} IN \(1, 2, 3, 4, 5, 6, 7, 8, 9, 10\)/
          end

          it 'returns ActiveRecord::Relation after complex associations, joins and wheres' do
            relation = Note.first.notable.articles.joins(:comments).where{comments.article_id != nil}

            relation.should be_kind_of(::ActiveRecord::Relation)
            relation.first.should be_kind_of(Article)
          end

          it 'uses Squeel and Arel at the same time' do
            relation = User.where{id.in([1,2,3]) & User.arel_table[:id].not_eq(nil) }

            if activerecord_version_at_least '4.2.0'
              relation.to_sql.should eq "
                SELECT #{Q}users#{Q}.* FROM #{Q}users#{Q}
                WHERE (#{Q}users#{Q}.#{Q}id#{Q} IN (1, 2, 3)
                AND #{Q}users#{Q}.#{Q}id#{Q} IS NOT NULL)
              ".squish
            else
              relation.to_sql.should match /SELECT #{Q}users#{Q}.\* FROM #{Q}users#{Q}\s+WHERE \(\(#{Q}users#{Q}.#{Q}id#{Q} IN \(1, 2, 3\) AND #{Q}users#{Q}.#{Q}id#{Q} IS NOT NULL\)\)/
            end

            relation = User.where {
              (id.in([1,2,3]) | User.arel_table[:id].eq(1)) &
              ((id == 1) | User.arel_table[:id].not_eq(nil)) }

            if activerecord_version_at_least '4.2.0'
              relation.to_sql.should eq "
                SELECT #{Q}users#{Q}.*
                FROM #{Q}users#{Q}
                WHERE ((#{Q}users#{Q}.#{Q}id#{Q} IN (1, 2, 3) OR #{Q}users#{Q}.#{Q}id#{Q} = 1)
                AND (#{Q}users#{Q}.#{Q}id#{Q} = 1 OR #{Q}users#{Q}.#{Q}id#{Q} IS NOT NULL))
              ".squish
            else
              relation.to_sql.should match /SELECT #{Q}users#{Q}.\* FROM #{Q}users#{Q}\s+WHERE \(\(\(#{Q}users#{Q}.#{Q}id#{Q} IN \(1, 2, 3\) OR #{Q}users#{Q}.#{Q}id#{Q} = 1\) AND \(#{Q}users#{Q}.#{Q}id#{Q} = 1 OR #{Q}users#{Q}.#{Q}id#{Q} IS NOT NULL\)\)\)/
            end
          end

          it "large than & less than" do
            if activerecord_version_at_least '4.1.0'
              relation = User.where { created_at <= 1.hours.ago }
              expect { relation.to_sql }.not_to raise_error

              relation = User.where { created_at < 1.hours.ago }
              expect { relation.to_sql }.not_to raise_error
            else
              pending 'Unsupported under Rails 4.1'
            end
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
            relation.to_sql.should match /#{Q}notes#{Q}.#{Q}notable_type#{Q} = 'Article'/
          end

          it 'joins multiple polymorphic belongs_to associations' do
            relation = Note.joins{[notable(Article), notable(Person)]}
            relation.to_sql.should match /#{Q}notes#{Q}.#{Q}notable_type#{Q} = 'Article'/
            relation.to_sql.should match /#{Q}notes#{Q}.#{Q}notable_type#{Q} = 'Person'/
          end

          it "only joins once, even if two join types are used" do
            if activerecord_version_at_least('4.1.0')
              pending "It's unreasonable to join once only, in some cases, we need twice."
            else
              relation = Person.joins(:articles.inner, :articles.outer)
              relation.to_sql.scan("JOIN").size.should eq 1
            end
          end

          it 'joins a keypath' do
            relation = Note.joins{notable(Article).person.children}
            relation.to_sql.should match /SELECT #{Q}notes#{Q}.* FROM #{Q}notes#{Q} INNER JOIN #{Q}articles#{Q} ON #{Q}articles#{Q}.#{Q}id#{Q} = #{Q}notes#{Q}.#{Q}notable_id#{Q} AND #{Q}notes#{Q}.#{Q}notable_type#{Q} = 'Article' INNER JOIN #{Q}people#{Q} ON #{Q}people#{Q}.#{Q}id#{Q} = #{Q}articles#{Q}.#{Q}person_id#{Q} INNER JOIN #{Q}people#{Q} #{Q}children_people#{Q} ON #{Q}children_people#{Q}.#{Q}parent_id#{Q} = #{Q}people#{Q}.#{Q}id#{Q}/
          end

          it 'validates polymorphic relationship with source type' do
            if activerecord_version_at_least('4.0.0')
              relation = Group.joins{users}

              if MYSQL_ENV
                relation.to_sql.should match /#{Q}memberships#{Q}.#{Q}active#{Q} = 1/
              else
                relation.to_sql.should match /#{Q}memberships#{Q}.#{Q}active#{Q} = 't'/
              end

              relation.to_sql.should match /#{Q}memberships#{Q}.#{Q}member_type#{Q} = 'User'/
              relation.to_sql.should match /INNER JOIN #{Q}users#{Q} ON #{Q}users#{Q}.#{Q}id#{Q} = #{Q}memberships#{Q}.#{Q}member_id#{Q}/
              relation.to_sql.should match /INNER JOIN #{Q}memberships#{Q} ON #{Q}memberships#{Q}.#{Q}group_id#{Q} = #{Q}groups#{Q}.#{Q}id#{Q}/
            elsif activerecord_version_at_least('3.2.7')
              Group.first.users.to_sql.should match /#{Q}memberships#{Q}.#{Q}member_type#{Q} = 'User'/
            else
              Group.first.users.size.should eq 1
            end
          end

          it 'joins an ActiveRecord::Relation subquery' do
            subquery = OrderItem.
              group(:orderable_id).
              select { [orderable_id, sum(quantity * unit_price).as(amount)] }

            relation = Seat.
              joins { [payment.outer,
                       subquery.as('seat_order_items').on { id == seat_order_items.orderable_id}.outer] }.
              select { [seat_order_items.amount, "seats.*"] }.
              where { seat_order_items.amount > 0 }

            relation.debug_sql.should match /SELECT #{Q}seat_order_items#{Q}.#{Q}amount#{Q}, seats.\* FROM #{Q}seats#{Q} LEFT OUTER JOIN #{Q}payments#{Q} ON #{Q}payments#{Q}.#{Q}id#{Q} = #{Q}seats#{Q}.#{Q}payment_id#{Q} LEFT OUTER JOIN \(SELECT #{Q}order_items#{Q}.#{Q}orderable_id#{Q}, sum\(#{Q}order_items#{Q}.#{Q}quantity#{Q} \* #{Q}order_items#{Q}.#{Q}unit_price#{Q}\) AS amount FROM #{Q}order_items#{Q}\s+GROUP BY #{Q}order_items#{Q}.#{Q}orderable_id#{Q}\) seat_order_items ON #{Q}seats#{Q}.#{Q}id#{Q} = #{Q}seat_order_items#{Q}.#{Q}orderable_id#{Q} WHERE #{Q}seat_order_items#{Q}.#{Q}amount#{Q} > 0/
            relation.to_a.should have(10).seats
            relation.to_a.second.amount.to_i.should eq(10)
          end

          it 'joins from an association with default scopes' do
            if activerecord_version_at_least('3.1.0')
              if MYSQL_ENV
                User.first.groups.to_sql.should match /#{Q}memberships#{Q}.#{Q}active#{Q} = 1/
              else
                User.first.groups.to_sql.should match /#{Q}memberships#{Q}.#{Q}active#{Q} = 't'/
              end
            else
              pending "Rails 3.0.x doesn't support to_sql in an association."
            end
          end

          it 'default scopes with multiple wheres' do
            if activerecord_version_at_least('4.0.0')
              relation = Dept.joins { people_named_bill_with_low_salary }

              relation.to_sql.should eq "
                  SELECT #{Q}depts#{Q}.*
                  FROM #{Q}depts#{Q}
                  INNER JOIN #{Q}people#{Q} ON
                    #{Q}people#{Q}.#{Q}dept_id#{Q} = #{Q}depts#{Q}.#{Q}id#{Q} AND
                    #{Q}people#{Q}.#{Q}name#{Q} = 'Bill' AND
                    #{Q}people#{Q}.#{Q}salary#{Q} < 20000
                ".squish
            else
              pending "Rails 3.x doesn't support default scope in joins"
            end
          end
        end

        describe '#having' do

          it 'builds options with a block' do
            standard = Person.having(:name => 'bob')
            block = Person.having{{name => 'bob'}}
            block.to_sql.should eq standard.to_sql
          end

          it 'allows complex conditions on aggregate columns' do
            if SQLITE_ENV
              relation = Person.group(:parent_id).having{salary == max(salary)}
              relation.first.name.should eq Person.last.name
            else
              pending "MySQL & PG don't support this type of group & having clauses, don't use it."
            end
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
            block.to_sql.should match /ORDER BY #{Q}people#{Q}.#{Q}name#{Q}/
          end

          it 'allows AR 4.0-style hash options' do
            if activerecord_version_at_least '4.0.0'
              block = Person.order(:name => :desc)
              block.to_sql.should match /ORDER BY #{Q}people#{Q}.#{Q}name#{Q} DESC/
            else
              pending 'Not required in AR versions < 4.0.0'
            end
          end

          it 'allows ordering by an attributes of a joined table' do
            relation = Article.joins(:person).order { person.id.asc }
            relation.to_sql.should match /ORDER BY #{Q}people#{Q}.#{Q}id#{Q} ASC/
          end

          it 'orders chain in correct sequence' do
            relation = Article.order {id.asc}.order {title.desc}
            relation.to_sql.should match /#{Q}articles#{Q}.#{Q}id#{Q} ASC, #{Q}articles#{Q}.#{Q}title#{Q} DESC/
          end

        end

        describe '#reorder' do
          before do
            @standard = Person.order(:name)
          end

          it 'builds options with a block' do
            block = @standard.reorder{id}
            block.to_sql.should_not eq @standard.to_sql
            block.to_sql.should match /ORDER BY #{Q}people#{Q}.#{Q}id#{Q}/
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
            expected = /SELECT #{Q}sub#{Q}.#{Q}name#{Q} AS aliased_name FROM \(SELECT #{Q}people#{Q}.#{Q}name#{Q} FROM #{Q}people#{Q}\s*\) sub/
            block = Person.from{Person.select{name}.as('sub')}.
              select{sub.name.as('aliased_name')}
            sql = block.to_sql
            sql.should match expected
          end

          it 'creates froms from literals' do
            expected = /SELECT #{Q}people#{Q}.* FROM sub/
            relation = Person.from('sub')
            sql = relation.to_sql
            sql.should match expected
          end

          it 'creates froms from relations' do
            if activerecord_version_at_least '4.0.0'
              expected = "SELECT #{Q}people#{Q}.* FROM (SELECT #{Q}people#{Q}.* FROM #{Q}people#{Q}) alias"
              relation = Person.from(Person.all, 'alias')
              sql = relation.to_sql
              sql.should == expected
            else
              pending 'Unsupported before ActiveRecord 4.0'
            end
          end

          it 'binds params from CollectionProxy subquery' do
            if activerecord_version_at_least('3.1.0')
              first_article = Article.first
              expected_tags = Tag.where(id: [1,2,3]).order{name}.to_a

              expected_tags.should == Tag.from{first_article.tags.as(Tag.table_name)}.order{tags.name}.to_a
            else
              pending "ActiveRecord 3.0.x doesn't support CollectionProxy chain."
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
            if activerecord_version_at_least('4.0.0')
              wheres.flatten.should have(1).equality
              wheres.flatten.last.should be_kind_of(Arel::Nodes::Equality)
            else
              wheres.should eq [{:name => 'bob'}]
            end
          end

        end

        describe '#debug_sql' do

          it 'returns the query that would be run against the database, even if eager loading' do
            relation = Person.includes(:comments, :articles).
              where(:comments => {:body => 'First post!'}).
              where(:articles => {:title => 'Hello, world!'})
            if activerecord_version_at_least('4.1.0')
              relation.debug_sql.should_not eq relation.arel.to_sql
            else
              relation.debug_sql.should_not eq relation.to_sql
            end
            relation.debug_sql.should match /SELECT #{Q}people#{Q}.#{Q}id#{Q} AS t0_r0/
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

        describe '#where_unscoping' do

          it "doesn't ruin everything when predicate expression in where_values doesn't respond to :symbol method" do
            unless activerecord_version_at_least '4.2.0'
              if activerecord_version_at_least '4.0.0'
                order_items = OrderItem.where{quantity == 0}.where{unit_price / 2 == 5}
                expect { order_items.unscope(where: :quantity) }.should_not raise_error
                order_items.to_sql.should_not match /#{Q}order_items#{Q}.#{Q}quantity#{Q} = 0/
              else
                pending 'Unsupported on AR versions < 4.0.0'
              end
            else
              pending 'Not required in AR versions > 4.2.0'
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
            sql.should match /#{Q}people#{Q}.#{Q}name#{Q} = 'bob'/
            sql.should match /#{Q}people#{Q}.#{Q}salary#{Q} = 100000/
          end

          it 'merges relations with a different base' do
            relation = Person.where{name == 'bob'}.joins(:articles).merge(Article.where{title == 'Hello world!'})
            sql = relation.to_sql
            sql.should match /INNER JOIN #{Q}articles#{Q} ON #{Q}articles#{Q}.#{Q}person_id#{Q} = #{Q}people#{Q}.#{Q}id#{Q}/
            sql.should match /#{Q}people#{Q}.#{Q}name#{Q} = 'bob'/
            sql.should match /#{Q}articles#{Q}.#{Q}title#{Q} = 'Hello world!'/
          end

          it 'does not break hm:t with conditions' do
            relation = Person.first.condition_article_comments
            sql =
              if activerecord_version_at_least('4.1.0')
                relation.to_sql
              else
                relation.scoped.to_sql
              end
            sql.should match /#{Q}articles#{Q}.#{Q}title#{Q} = 'Condition'/
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
              relation =
                if activerecord_version_at_least('4.1.0')
                  PersonNamedBill.rewhere(name: 'Ernie')
                  # Or PersonNamedBill.unscope(where: :name).where { name == 'Ernie' }
                else
                  PersonNamedBill.where{name == 'Ernie'}
                end
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
            sql.should match /#{Q}articles#{Q}.#{Q}title#{Q} = 'hi'/
            sql.should match /#{Q}articles_with_conditions_people#{Q}.#{Q}title#{Q} = 'yo'/
          end

          it "doesn't ruin everything when a scope returns nil" do
            relation = Person.nil_scope
            if activerecord_version_at_least('4.1.0')
              relation.should eq Person.all
            else
              relation.should eq Person.scoped
            end
          end

          it "doesn't ruin everything when a group exists" do
            count_hash = {}
            if activerecord_version_at_least('4.1.0')
              relation = Person.all.merge(Person.group{name})
              expect { count_hash = relation.count }.should_not raise_error
              count_hash.size.should eq Person.all.size
            else
              relation = Person.scoped.merge(Person.group{name})
              expect { count_hash = relation.count }.should_not raise_error
              count_hash.size.should eq Person.scoped.size
            end

            count_hash.values.all? {|v| v == 1}.should be_true
            count_hash.keys.should =~ Person.select{name}.map(&:name)
          end

          it "doesn't merge the default scope more than once" do
            relation =
              if activerecord_version_at_least('4.1.0')
                PersonNamedBill.all.highly_compensated.ending_with_ill
              else
                PersonNamedBill.scoped.highly_compensated.ending_with_ill
              end
            sql = relation.to_sql
            sql.scan(/#{Q}people#{Q}.#{Q}name#{Q} = 'Bill'/).should have(1).item
            sql.scan(/#{Q}people#{Q}.#{Q}name#{Q} [I]*LIKE '%ill'/).should have(1).item
            sql.scan(/#{Q}people#{Q}.#{Q}salary#{Q} > 200000/).should have(1).item
            sql.scan(/#{Q}people#{Q}.#{Q}id#{Q}/).should have(1).item
          end

          it "doesn't hijack the table name when merging a relation with different base and default_scope" do
            relation =
              if activerecord_version_at_least('4.1.0')
                Article.joins(:person).merge(PersonNamedBill.all)
              else
                Article.joins(:person).merge(PersonNamedBill.scoped)
              end
            sql = relation.to_sql
            sql.scan(/#{Q}people#{Q}.#{Q}name#{Q} = 'Bill'/).should have(1).item
          end

          it 'merges scopes that contain functions' do
            relation =
              if activerecord_version_at_least('4.1.0')
                PersonNamedBill.all.with_salary_equal_to(100)
              else
                PersonNamedBill.scoped.with_salary_equal_to(100)
              end
            sql = relation.to_sql
            sql.should match /abs\(#{Q}people#{Q}.#{Q}salary#{Q}\) = 100/
          end

          it 'uses last equality when merging two scopes with identical function equalities' do
            if activerecord_version_at_least('4.1.0')
              pending "Named Functions can't be unscoped"
            else
              relation = PersonNamedBill.scoped.with_salary_equal_to(100).
                                                with_salary_equal_to(200)
              sql = relation.to_sql
              sql.should_not match /abs\(#{Q}people#{Q}.#{Q}salary#{Q}\) = 100/
              sql.should match /abs\(#{Q}people#{Q}.#{Q}salary#{Q}\) = 200/
            end
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
              vals.should have(20).items
            end

            if activerecord_version_at_least('3.1.0')
              queries.should have(2).queries
            else
              puts 'skips count of queries expectation'
            end

            matched_ids = queries.last.match(/IN \(([^)]*)/).captures.first
            matched_ids = matched_ids.split(/,\s*/).map(&:to_i)
            matched_ids.should =~ [1, 2, 3, 4, 5 ,6 ,7 ,8 ,9 ,10]
          end

        end

      end
    end
  end
end
