require 'spec_helper'

module Squeel
  module Adapters
    module ActiveRecord
      describe JoinDependencyExtensions do
        before do
          @jd = new_join_dependency(Person, {}, [])
        end

        it 'joins with symbols' do
          @jd.send(:build, :articles => :comments)
          @jd.join_associations.should have(2).associations
          @jd.join_associations.each do |association|
            association.join_type.should eq Arel::InnerJoin
          end
        end

        it 'joins has_many :through associations' do
          @jd.send(:build, :authored_article_comments)
          @jd.join_associations.should have(1).association
          @jd.join_associations.first.table_name.should eq 'comments'
        end

        it 'joins with stubs' do
          @jd.send(:build, Nodes::Stub.new(:articles) => Nodes::Stub.new(:comments))
          @jd.join_associations.should have(2).associations
          @jd.join_associations.each do |association|
            association.join_type.should eq Arel::InnerJoin
          end
          @jd.join_associations[0].table_name.should eq 'articles'
          @jd.join_associations[1].table_name.should eq 'comments'
        end

        it 'joins with key paths' do
          @jd.send(:build, dsl{children.children.parent})
          @jd.join_associations.should have(3).associations
          @jd.join_associations.each do |association|
            association.join_type.should eq Arel::InnerJoin
          end
          @jd.join_associations[0].aliased_table_name.should eq 'children_people'
          @jd.join_associations[1].aliased_table_name.should eq 'children_people_2'
          @jd.join_associations[2].aliased_table_name.should eq 'parents_people'
        end

        it 'joins with key paths as keys' do
          @jd.send(:build, dsl{{children.parent => parent}})
          @jd.join_associations.should have(3).associations
          @jd.join_associations.each do |association|
            association.join_type.should eq Arel::InnerJoin
          end
          @jd.join_associations[0].aliased_table_name.should eq 'children_people'
          @jd.join_associations[1].aliased_table_name.should eq 'parents_people'
          @jd.join_associations[2].aliased_table_name.should eq 'parents_people_2'
        end

        it 'joins using outer joins' do
          @jd.send(:build, :articles.outer => :comments.outer)
          @jd.join_associations.should have(2).associations
          @jd.join_associations.each do |association|
            association.join_type.should eq Arel::OuterJoin
          end
        end

      end
    end
  end
end