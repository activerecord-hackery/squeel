module Squeel
  module Adapters
    module ActiveRecord
      describe JoinAssociation do
        before do
          @jd = ::ActiveRecord::Associations::JoinDependency.new(Note, {}, [])
          @notable = Note.reflect_on_association(:notable)
        end

        it 'accepts a 4th parameter to set a polymorphic class' do
          join_association = JoinAssociation.new(@notable, @jd, @jd.join_base, Article)
          join_association.reflection.klass.should eq Article
        end

      end
    end
  end
end