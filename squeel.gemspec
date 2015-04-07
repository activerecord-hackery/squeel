# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "squeel/version"

Gem::Specification.new do |s|
  s.name        = "squeel"
  s.version     = Squeel::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Ernie Miller", "Xiang Li"]
  s.email       = ["ernie@erniemiller.org", "bigxiang@gmail.com"]
  s.homepage    = "https://github.com/ernie/squeel"
  s.summary     = %q{Active Record, improved.}
  s.description = %q{
      Squeel unlocks the power of Arel in your Rails application with
      a handy block-based syntax. You can write subqueries, access named
      functions provided by your RDBMS, and more, all without writing
      SQL strings. Supporting Rails 3 and 4.
    }
  s.rubyforge_project = "squeel"

  s.add_dependency 'activerecord', '>= 3.0'
  s.add_dependency 'activesupport', '>= 3.0'
  s.add_dependency 'polyamorous', '~> 1.1'
  s.add_development_dependency 'rspec', '~> 2.6.0'
  s.add_development_dependency 'faker', '~> 0.9.5'
  s.add_development_dependency 'sqlite3', '~> 1.3.3'
  s.add_development_dependency 'mysql', '~> 2.9.1'
  s.add_development_dependency 'mysql2', '~> 0.3.16'
  s.add_development_dependency 'pg', '~> 0.17.1'
  s.add_development_dependency 'git_pretty_accept', '~> 0.4.0'
  s.add_development_dependency 'pry'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
