case ActiveRecord::VERSION::MAJOR
when 3
  ActiveRecord::Relation.send :include, Squeel::Nodes::Aliasing
  require 'squeel/adapters/active_record/join_dependency_extensions'
  require 'squeel/adapters/active_record/base_extensions'
  ActiveRecord::Base.extend Squeel::Adapters::ActiveRecord::BaseExtensions

  case ActiveRecord::VERSION::MINOR
  when 0
    require 'squeel/adapters/active_record/3.0/compat'
    require 'squeel/adapters/active_record/3.0/relation_extensions'
    require 'squeel/adapters/active_record/3.0/association_preload_extensions'
    require 'squeel/adapters/active_record/3.0/context'

    ActiveRecord::Relation.send :include, Squeel::Adapters::ActiveRecord::RelationExtensions
    ActiveRecord::Associations::ClassMethods::JoinDependency.send :include, Squeel::Adapters::ActiveRecord::JoinDependencyExtensions
    ActiveRecord::Base.extend Squeel::Adapters::ActiveRecord::AssociationPreloadExtensions
  when 1
    require 'squeel/adapters/active_record/3.1/relation_extensions'
    require 'squeel/adapters/active_record/3.1/preloader_extensions'
    require 'squeel/adapters/active_record/3.1/context'
    
    ActiveRecord::Relation.send :include, Squeel::Adapters::ActiveRecord::RelationExtensions
    ActiveRecord::Associations::JoinDependency.send :include, Squeel::Adapters::ActiveRecord::JoinDependencyExtensions
    ActiveRecord::Associations::Preloader.send :include, Squeel::Adapters::ActiveRecord::PreloaderExtensions
  else
    require 'squeel/adapters/active_record/relation_extensions'
    require 'squeel/adapters/active_record/preloader_extensions'
    require 'squeel/adapters/active_record/context'

    ActiveRecord::Relation.send :include, Squeel::Adapters::ActiveRecord::RelationExtensions
    ActiveRecord::Associations::JoinDependency.send :include, Squeel::Adapters::ActiveRecord::JoinDependencyExtensions
    ActiveRecord::Associations::Preloader.send :include, Squeel::Adapters::ActiveRecord::PreloaderExtensions
  end
else
  raise NotImplementedError, "Squeel does not support ActiveRecord version #{ActiveRecord::VERSION::STRING}"
end