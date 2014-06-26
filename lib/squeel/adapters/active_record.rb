case ActiveRecord::VERSION::MAJOR
when 3, 4
  ActiveRecord::Relation.send :include, Squeel::Nodes::Aliasing
  require 'squeel/adapters/active_record/base_extensions'

  adapter_directory = "#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"
  Dir[File.expand_path("../active_record/#{adapter_directory}/*.rb", __FILE__)].each do |f|
    require f
  end
else
  raise NotImplementedError, "Squeel does not support Active Record version #{ActiveRecord::VERSION::STRING}"
end
