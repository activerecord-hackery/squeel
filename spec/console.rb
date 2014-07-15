Bundler.setup
require 'pp'
require 'active_record'
require 'active_support'
require 'faker'

Dir[File.expand_path('../helpers/*.rb', __FILE__)].each do |f|
  require f
end
require File.expand_path('../support/schema.rb', __FILE__)
require File.expand_path('../support/models.rb', __FILE__)

Models.make

require 'squeel'

