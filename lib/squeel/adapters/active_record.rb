require 'squeel/adapters/active_record/relation'
require 'squeel/adapters/active_record/join_dependency'
require 'squeel/adapters/active_record/join_association'

ActiveRecord::Relation.send :include, Squeel::Adapters::ActiveRecord::Relation
ActiveRecord::Associations::JoinDependency.send :include, Squeel::Adapters::ActiveRecord::JoinDependency