ActiveRecord::Relation.send :include, Squeel::Nodes::Aliasing

case ActiveRecord::VERSION::MAJOR
when 3
  case ActiveRecord::VERSION::MINOR
  when 0
    require 'squeel/adapters/active_record/3.0/compat'
    require 'squeel/adapters/active_record/3.0/relation'
    require 'squeel/adapters/active_record/3.0/join_dependency'
    require 'squeel/adapters/active_record/3.0/join_association'
    require 'squeel/adapters/active_record/3.0/association_preload'
    require 'squeel/adapters/active_record/3.0/context'

    ActiveRecord::Relation.send :include, Squeel::Adapters::ActiveRecord::Relation
    ActiveRecord::Associations::ClassMethods::JoinDependency.send :include, Squeel::Adapters::ActiveRecord::JoinDependency
    ActiveRecord::Base.extend Squeel::Adapters::ActiveRecord::AssociationPreload
  else
    require 'squeel/adapters/active_record/relation'
    require 'squeel/adapters/active_record/join_dependency'
    require 'squeel/adapters/active_record/join_association'
    require 'squeel/adapters/active_record/preloader'
    require 'squeel/adapters/active_record/context'

    ActiveRecord::Relation.send :include, Squeel::Adapters::ActiveRecord::Relation
    ActiveRecord::Associations::JoinDependency.send :include, Squeel::Adapters::ActiveRecord::JoinDependency
    ActiveRecord::Associations::Preloader.send :include, Squeel::Adapters::ActiveRecord::Preloader
  end
else
  raise NotImplementedError, "Squeel does not support ActiveRecord version #{ActiveRecord::VERSION::STRING}"
end