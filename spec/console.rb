Bundler.setup
require 'machinist/active_record'
require 'sham'
require 'faker'

Dir[File.expand_path('../helpers/*.rb', __FILE__)].each do |f|
  require f
end
require File.expand_path('../support/schema.rb', __FILE__)
require File.expand_path('../support/models.rb', __FILE__)

Sham.define do
  name        { Faker::Name.name }
  title       { Faker::Lorem.sentence }
  body        { Faker::Lorem.paragraph }
  salary      {|index| 30000 + (index * 1000)}
  tag_name    { Faker::Lorem.words(3).join(' ') }
  note        { Faker::Lorem.words(7).join(' ') }
  object_name { Faker::Lorem.words(1).first }
end

Models.make

require 'squeel'

