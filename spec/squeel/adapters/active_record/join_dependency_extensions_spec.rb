require 'spec_helper'

module Squeel
  module Adapters
    module ActiveRecord
      describe "JoinDependencyExtensions" do
        it 'joins with symbols' do
          @jd = new_join_dependency(Person, { :articles => :comments }, [])

          if activerecord_version_at_least('4.2.0')
            @jd.join_constraints([]).should have(2).join_info
            @jd.join_constraints([]).map(&:joins).flatten.each do |join|
              join.class.should eq Squeel::InnerJoin
            end
          elsif activerecord_version_at_least('4.1.0')
            @jd.join_constraints([]).should have(2).joins
            @jd.join_constraints([]).each do |join|
              join.class.should eq Squeel::InnerJoin
            end
          else
            @jd.join_associations.should have(2).associations
            @jd.join_associations.each do |association|
              association.join_type.should eq Squeel::InnerJoin
            end
          end
        end

        it 'joins has_many :through associations' do
          @jd = new_join_dependency(Person, :authored_article_comments, [])

          if activerecord_version_at_least('4.2.0')
            @jd.join_constraints([]).should have(1).join_info
            @jd.join_root.children.first.table_name.should eq 'comments'
          elsif activerecord_version_at_least('4.1.0')
            @jd.join_constraints([]).should have(2).joins
            @jd.join_root.children.first.table_name.should eq 'comments'
          else
            @jd.join_associations.should have(1).association
            @jd.join_associations.first.table_name.should eq 'comments'
          end
        end

        it 'joins with stubs' do
          @jd = new_join_dependency(Person, { Squeel::Nodes::Stub.new(:articles) => Squeel::Nodes::Stub.new(:comments) }, [])

          if activerecord_version_at_least('4.2.0')
            @jd.join_constraints([]).should have(2).join_info
            @jd.join_constraints([]).map(&:joins).flatten.each do |join|
              join.class.should eq Squeel::InnerJoin
            end
            @jd.join_root.children.first.table_name.should eq 'articles'
            @jd.join_root.children.first.children.first.table_name.should eq 'comments'
          elsif activerecord_version_at_least('4.1.0')
            @jd.join_constraints([]).should have(2).joins
            @jd.join_constraints([]).each do |join|
              join.class.should eq Squeel::InnerJoin
            end
            @jd.join_root.children.first.table_name.should eq 'articles'
            @jd.join_root.children.first.children.first.table_name.should eq 'comments'
          else
            @jd.join_associations.should have(2).associations
            @jd.join_associations.each do |association|
              association.join_type.should eq Squeel::InnerJoin
            end
            @jd.join_associations[0].table_name.should eq 'articles'
            @jd.join_associations[1].table_name.should eq 'comments'
          end
        end

        it 'joins with key paths' do
          @jd = new_join_dependency(Person, dsl{ children.children.parent }, [])

          if activerecord_version_at_least('4.2.0')
            @jd.join_constraints([]).should have(3).join_info
            @jd.join_constraints([]).map(&:joins).flatten.each do |join|
              join.class.should eq Squeel::InnerJoin
            end
            (children_people = @jd.join_root.children.first).aliased_table_name.should eq 'children_people'
            (children_people2 = children_people.children.first).aliased_table_name.should eq 'children_people_2'
            children_people2.children.first.aliased_table_name.should eq 'parents_people'
          elsif activerecord_version_at_least('4.1.0')
            @jd.join_constraints([]).should have(3).joins
            @jd.join_constraints([]).each do |join|
              join.class.should eq Squeel::InnerJoin
            end
            (children_people = @jd.join_root.children.first).aliased_table_name.should eq 'children_people'
            (children_people2 = children_people.children.first).aliased_table_name.should eq 'children_people_2'
            children_people2.children.first.aliased_table_name.should eq 'parents_people'
          else
            @jd.join_associations.should have(3).associations
            @jd.join_associations.each do |association|
              association.join_type.should eq Squeel::InnerJoin
            end
            @jd.join_associations[0].aliased_table_name.should eq 'children_people'
            @jd.join_associations[1].aliased_table_name.should eq 'children_people_2'
            @jd.join_associations[2].aliased_table_name.should eq 'parents_people'
          end
        end

        it 'joins with key paths as keys' do
          @jd = new_join_dependency(Person, dsl{ { children.parent => parent } }, [])

          if activerecord_version_at_least('4.2.0')
            @jd.join_constraints([]).should have(3).join_info
            @jd.join_constraints([]).map(&:joins).flatten.each do |join|
              join.class.should eq Squeel::InnerJoin
            end
            (children_people = @jd.join_root.children.first).aliased_table_name.should eq 'children_people'
            (parents_people = children_people.children.first).aliased_table_name.should eq 'parents_people'
            parents_people.children.first.aliased_table_name.should eq 'parents_people_2'
          elsif activerecord_version_at_least('4.1.0')
            @jd.join_constraints([]).should have(3).joins
            @jd.join_constraints([]).each do |join|
              join.class.should eq Squeel::InnerJoin
            end
            (children_people = @jd.join_root.children.first).aliased_table_name.should eq 'children_people'
            (parents_people = children_people.children.first).aliased_table_name.should eq 'parents_people'
            parents_people.children.first.aliased_table_name.should eq 'parents_people_2'
          else
            @jd.join_associations.should have(3).associations
            @jd.join_associations.each do |association|
              association.join_type.should eq Squeel::InnerJoin
            end
            @jd.join_associations[0].aliased_table_name.should eq 'children_people'
            @jd.join_associations[1].aliased_table_name.should eq 'parents_people'
            @jd.join_associations[2].aliased_table_name.should eq 'parents_people_2'
          end
        end

        it 'joins using outer joins' do
          @jd = new_join_dependency(Person, { :articles.outer => :comments.outer }, [])

          if activerecord_version_at_least('4.2.0')
            @jd.join_constraints([]).should have(2).join_info
            @jd.join_constraints([]).map(&:joins).flatten.each do |join|
              join.class.should eq Squeel::OuterJoin
            end
          elsif activerecord_version_at_least('4.1.0')
            @jd.join_constraints([]).should have(2).joins
            @jd.join_constraints([]).each do |join|
              join.class.should eq Squeel::OuterJoin
            end
          else
            @jd.join_associations.should have(2).associations
            @jd.join_associations.each do |association|
              association.join_type.should eq Squeel::OuterJoin
            end
          end
        end
      end
    end
  end
end
