require 'spec_helper'

module Squeel
  module Adapters
    module ActiveRecord
      describe Context do
        before do
          @jd = new_join_dependency(Person, {
                 :children => {
                   :children => {
                     :parent => :parent
                   }
                 }
               }, [])
          @c = Context.new(@jd)
        end

        it 'contextualizes join parts with the proper alias' do
          table = if activerecord_version_at_least('4.1.0')
              @c.contextualize @jd.join_root.children.last.children.last.children.last.children.last
            else
              @c.contextualize @jd.join_associations.last
            end
          table.table_alias.should eq 'parents_people_2'
        end

        it 'contextualizes symbols as a generic table' do
          table = @c.contextualize :table
          table.name.should eq 'table'
          table.table_alias.should be_nil
        end

        it 'contextualizes polymorphic Join nodes to the arel_table of their klass' do
          table = @c.contextualize Nodes::Join.new(:notable, Squeel::InnerJoin, Article)
          table.name.should eq 'articles'
          table.table_alias.should be_nil
        end

        it 'contextualizes non-polymorphic Join nodes to the table for their name' do
          table = @c.contextualize Nodes::Join.new(:notes, Squeel::InnerJoin)
          table.name.should eq 'notes'
          table.table_alias.should be_nil
        end

      end
    end
  end
end
