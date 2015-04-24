require "./lib/salesforce_bulk/version"

Gem::Specification.new do |s|
  s.name        = 'salesforcebulk'
  s.version     = SalesforceBulk::VERSION
  s.summary     = "Full capability support for the Salesforce Bulk API."
  s.description = "This gem is a simple interface to the Salesforce Bulk API providing full support for insert, update, upsert, delete, and query actions while allowing you to specify multiple batches per job to process data fast. Gem includes unit tests."

  s.author   = 'Javier Julio'
  s.email    = 'jjfutbol@gmail.com'
  s.homepage = 'https://github.com/javierjulio/salesforce_bulk'

  s.files         = `git ls-files lib README.md`.split("\n")

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
