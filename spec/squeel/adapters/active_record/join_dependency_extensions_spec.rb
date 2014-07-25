require 'spec_helper'

module Squeel
  module Adapters
    module ActiveRecord
      describe "JoinDependencyExtensions" do
        it 'joins with symbols' do
          @jd = new_join_dependency(Person, { :articles => :comments }, [])

          if activerecord_version_at_least('4.2.0')
            expect(@jd.join_constraints([]).size).to eq(2)
            @jd.join_constraints([]).map(&:joins).flatten.each do |join|
              expect(join.class).to eq Squeel::InnerJoin
            end
          elsif activerecord_version_at_least('4.1.0')
            expect(@jd.join_constraints([]).size).to eq(2)
            @jd.join_constraints([]).each do |join|
              expect(join.class).to eq Squeel::InnerJoin
            end
          else
            expect(@jd.join_associations.size).to eq(2)
            @jd.join_associations.each do |association|
              expect(association.join_type).to eq Squeel::InnerJoin
            end
          end
        end

        it 'joins has_many :through associations' do
          @jd = new_join_dependency(Person, :authored_article_comments, [])

          if activerecord_version_at_least('4.2.0')
            expect(@jd.join_constraints([]).size).to eq(1)
            expect(@jd.join_root.children.first.table_name).to eq 'comments'
          elsif activerecord_version_at_least('4.1.0')
            expect(@jd.join_constraints([]).size).to eq(2)
            expect(@jd.join_root.children.first.table_name).to eq 'comments'
          else
            expect(@jd.join_associations.size).to eq(1)
            expect(@jd.join_associations.first.table_name).to eq 'comments'
          end
        end

        it 'joins with stubs' do
          @jd = new_join_dependency(Person, { Squeel::Nodes::Stub.new(:articles) => Squeel::Nodes::Stub.new(:comments) }, [])

          if activerecord_version_at_least('4.2.0')
            expect(@jd.join_constraints([]).size).to eq(2)
            @jd.join_constraints([]).map(&:joins).flatten.each do |join|
              expect(join.class).to eq Squeel::InnerJoin
            end
            expect(@jd.join_root.children.first.table_name).to eq 'articles'
            expect(@jd.join_root.children.first.children.first.table_name).to eq 'comments'
          elsif activerecord_version_at_least('4.1.0')
            expect(@jd.join_constraints([]).size).to eq(2)
            @jd.join_constraints([]).each do |join|
              expect(join.class).to eq Squeel::InnerJoin
            end
            expect(@jd.join_root.children.first.table_name).to eq 'articles'
            expect(@jd.join_root.children.first.children.first.table_name).to eq 'comments'
          else
            expect(@jd.join_associations.size).to eq(2)
            @jd.join_associations.each do |association|
              expect(association.join_type).to eq Squeel::InnerJoin
            end
            expect(@jd.join_associations[0].table_name).to eq 'articles'
            expect(@jd.join_associations[1].table_name).to eq 'comments'
          end
        end

        it 'joins with key paths' do
          @jd = new_join_dependency(Person, dsl{ children.children.parent }, [])

          if activerecord_version_at_least('4.2.0')
            expect(@jd.join_constraints([]).size).to eq(3)
            @jd.join_constraints([]).map(&:joins).flatten.each do |join|
              expect(join.class).to eq Squeel::InnerJoin
            end
            expect((children_people = @jd.join_root.children.first).aliased_table_name).to eq 'children_people'
            expect((children_people2 = children_people.children.first).aliased_table_name).to eq 'children_people_2'
            expect(children_people2.children.first.aliased_table_name).to eq 'parents_people'
          elsif activerecord_version_at_least('4.1.0')
            expect(@jd.join_constraints([]).size).to eq(3)
            @jd.join_constraints([]).each do |join|
              expect(join.class).to eq Squeel::InnerJoin
            end
            expect((children_people = @jd.join_root.children.first).aliased_table_name).to eq 'children_people'
            expect((children_people2 = children_people.children.first).aliased_table_name).to eq 'children_people_2'
            expect(children_people2.children.first.aliased_table_name).to eq 'parents_people'
          else
            expect(@jd.join_associations.size).to eq(3)
            @jd.join_associations.each do |association|
              expect(association.join_type).to eq Squeel::InnerJoin
            end
            expect(@jd.join_associations[0].aliased_table_name).to eq 'children_people'
            expect(@jd.join_associations[1].aliased_table_name).to eq 'children_people_2'
            expect(@jd.join_associations[2].aliased_table_name).to eq 'parents_people'
          end
        end

        it 'joins with key paths as keys' do
          @jd = new_join_dependency(Person, dsl{ { children.parent => parent } }, [])

          if activerecord_version_at_least('4.2.0')
            expect(@jd.join_constraints([]).size).to eq(3)
            @jd.join_constraints([]).map(&:joins).flatten.each do |join|
              expect(join.class).to eq Squeel::InnerJoin
            end
            expect((children_people = @jd.join_root.children.first).aliased_table_name).to eq 'children_people'
            expect((parents_people = children_people.children.first).aliased_table_name).to eq 'parents_people'
            expect(parents_people.children.first.aliased_table_name).to eq 'parents_people_2'
          elsif activerecord_version_at_least('4.1.0')
            expect(@jd.join_constraints([]).size).to eq(3)
            @jd.join_constraints([]).each do |join|
              expect(join.class).to eq Squeel::InnerJoin
            end
            expect((children_people = @jd.join_root.children.first).aliased_table_name).to eq 'children_people'
            expect((parents_people = children_people.children.first).aliased_table_name).to eq 'parents_people'
            expect(parents_people.children.first.aliased_table_name).to eq 'parents_people_2'
          else
            expect(@jd.join_associations.size).to eq(3)
            @jd.join_associations.each do |association|
              expect(association.join_type).to eq Squeel::InnerJoin
            end
            expect(@jd.join_associations[0].aliased_table_name).to eq 'children_people'
            expect(@jd.join_associations[1].aliased_table_name).to eq 'parents_people'
            expect(@jd.join_associations[2].aliased_table_name).to eq 'parents_people_2'
          end
        end

        it 'joins using outer joins' do
          @jd = new_join_dependency(Person, { :articles.outer => :comments.outer }, [])

          if activerecord_version_at_least('4.2.0')
            expect(@jd.join_constraints([]).size).to eq(2)
            @jd.join_constraints([]).map(&:joins).flatten.each do |join|
              expect(join.class).to eq Squeel::OuterJoin
            end
          elsif activerecord_version_at_least('4.1.0')
            expect(@jd.join_constraints([]).size).to eq(2)
            @jd.join_constraints([]).each do |join|
              expect(join.class).to eq Squeel::OuterJoin
            end
          else
            expect(@jd.join_associations.size).to eq(2)
            @jd.join_associations.each do |association|
              expect(association.join_type).to eq Squeel::OuterJoin
            end
          end
        end
      end
    end
  end
end
