require 'bundler/setup'
require 'rspec/core/rake_task'

Bundler::GemHelper.install_tasks

RSpec::Core::RakeTask.new(:spec) do |rspec|
  rspec.rspec_opts = ['--backtrace', '--color', '--format documentation']
end

task :default => 'test_sqlite3'

%w(sqlite3 mysql mysql2 postgresql).each do |adapter|
  namespace :test do
    task(adapter => ["#{adapter}:env", "spec"])
  end

  namespace adapter do
    task(:env) { ENV['SQ_DB'] = adapter }
  end

  task "test_#{adapter}" => ["#{adapter}:env", "test:#{adapter}"]
end

desc "Open an irb session with Squeel and the sample data used in specs"
task :console do
  require 'irb'
  require 'irb/completion'
  require 'console'
  ARGV.clear
  IRB.start
end
