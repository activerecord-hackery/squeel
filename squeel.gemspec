# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "squeel/version"

Gem::Specification.new do |s|
  s.name        = "squeel"
  s.version     = Squeel::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Ernie Miller"]
  s.email       = ["ernie@metautonomo.us"]
  s.homepage    = "http://metautonomo.us/projects/squeel"
  s.summary     = %q{ActiveRecord 3, improved.}
  s.description = %q{
      Squeel unlocks the power of ARel in your Rails 3 application with
      a handy block-based syntax. You can write subqueries, access named
      functions provided by your RDBMS, and more, all without writing
      SQL strings.
    }
  s.post_install_message = %q{
*** Thanks for installing Squeel! ***
Be sure to check out http://metautonomo.us/projects/squeel/ for a
walkthrough of Squeel's features, and click the donate link if
you're feeling especially appreciative. It'd help me justify this
"open source" stuff to my lovely wife. :)

}

  s.rubyforge_project = "squeel"

  s.add_dependency 'activerecord', '~> 3.0'
  s.add_dependency 'activesupport', '~> 3.0'
  s.add_development_dependency 'rspec', '~> 2.5.0'
  s.add_development_dependency 'machinist', '~> 1.0.6'
  s.add_development_dependency 'faker', '~> 0.9.5'
  s.add_development_dependency 'sqlite3', '~> 1.3.3'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
