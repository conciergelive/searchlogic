# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require File.expand_path('../lib/searchlogic/version', __FILE__)

Gem::Specification.new do |s|
  s.name        = "searchlogic"
  s.version     = Searchlogic::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Ben Johnson"]
  s.email       = ["bjohnson@binarylogic.com"]
  s.homepage    = "http://github.com/binarylogic/searchlogic"
  s.summary     = %q{Searchlogic makes using ActiveRecord named scopes easier and less repetitive.}
  s.description = %q{Searchlogic makes using ActiveRecord named scopes easier and less repetitive.}

  s.add_dependency 'activerecord', '>= 3.2', '< 5.0'
  s.add_dependency 'activesupport', '>= 3.2', '< 5.0'

  s.add_dependency 'ruby3-backward-compatibility'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'timecop'
  s.add_development_dependency 'pg'
  s.add_development_dependency 'pry', '>= 0'
  s.add_development_dependency 'pry-stack_explorer'
  s.add_development_dependency 'pry-rescue', '>= 0'
  s.add_development_dependency 'appraisal'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_paths = ["lib"]
end
