require 'squeel/adapters/active_record/relation'
require 'squeel/adapters/active_record/join_dependency'
require 'squeel/adapters/active_record/join_association'
require 'squeel/adapters/active_record/preloader'
require 'squeel/adapters/active_record/context'

ActiveRecord::Relation.send :include, Squeel::Adapters::ActiveRecord::Relation
ActiveRecord::Associations::JoinDependency.send :include, Squeel::Adapters::ActiveRecord::JoinDependency
ActiveRecord::Associations::Preloader.send :include, Squeel::Adapters::ActiveRecord::Preloader