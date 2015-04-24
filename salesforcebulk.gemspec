# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "salesforce_bulk/version"

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'salesforcebulk'
  s.version     = SalesforceBulk::VERSION
  s.summary     = %q{Full capability support for the Salesforce Bulk API.}
  s.description = %q{This gem is a simple interface to the Salesforce Bulk API providing full support for insert, update, upsert, delete, and query actions while allowing you to specify multiple batches per job to process data fast. Gem includes unit tests.}

  s.author   = 'Javier Julio'
  s.email    = 'jjfutbol@gmail.com'
  s.homepage = 'https://github.com/javierjulio/salesforce_bulk'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "activesupport", '>= 3.2.0', '< 4.1'
  s.add_dependency "xml-simple"

  s.add_development_dependency "rake"
  s.add_development_dependency "rdoc"
  s.add_development_dependency "mocha", '~> 0.13.0'
  s.add_development_dependency "shoulda", '~> 3.3.0'
  s.add_development_dependency "webmock", '~> 1.8.11'
  s.add_development_dependency 'minitest', '~> 4.3'
  s.add_development_dependency 'bump'
  s.add_development_dependency 'wwtd'
end
