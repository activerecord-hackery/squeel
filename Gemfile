source "http://rubygems.org"
gemspec

if ENV['RAILS_VERSION'] == 'release'
  gem 'activesupport'
  gem 'activerecord'
else
  gem 'arel',  :git => 'git://github.com/rails/arel.git'
  git 'git://github.com/rails/rails.git' do
    gem 'activesupport'
    gem 'activerecord'
  end
end