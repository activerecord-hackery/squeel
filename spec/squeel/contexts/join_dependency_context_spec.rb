require 'spec_helper'

module Squeel
  module Contexts
    describe JoinDependencyContext do
      before do
        @jd = ActiveRecord::Associations::JoinDependency.
             new(Person, {
               :children => {
                 :children => {
                   :parent => :parent
                 }
               }
             }, [])
        @c = JoinDependencyContext.new(@jd)
      end

      it 'finds associations' do
        last_association = @jd.join_parts.last
        next_to_last_association = @jd.join_parts[-2]

        @c.find(:parent, next_to_last_association).should eq last_association
      end

      it 'contextualizes join parts with the proper alias' do
        table = @c.contextualize @jd.join_parts.last
        table.table_alias.should eq 'parents_people_2'
      end

      it 'contextualizes symbols as a generic table' do
        table = @c.contextualize :table
        table.name.should eq 'table'
        table.table_alias.should be_nil
      end

      it 'contextualizes non-JoinPart/Symbols to the default join base table' do
        table = @c.contextualize nil
        table.name.should eq 'people'
        table.table_alias.should be_nil
      end
    end
  end
end