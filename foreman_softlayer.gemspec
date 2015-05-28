require File.expand_path('../lib/foreman_softlayer/version', __FILE__)
require 'date'

Gem::Specification.new do |s|
  s.name        = 'foreman_softlayer'
  s.version     = ForemanSoftlayer::VERSION
  s.date        = Date.today.to_s
  s.authors     = ['James Stuart']
  s.email       = ['software@jstuart.org']
  s.homepage    = 'https://github.com/jstuart/foreman-softlayer'
  s.summary     = 'Provision and manage Softlayer resources from Foreman.'
  # also update locale/gemspec.rb
  s.description = 'Provision and manage Softlayer resources from Foreman.'

  s.files = Dir['{app,config,db,lib,locale}/**/*'] + ['LICENSE', 'Rakefile', 'README.md']
  s.test_files = Dir['test/**/*']

  s.add_dependency 'deface'
  s.add_dependency 'fog-softlayer', '>= 0.4.6'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'rdoc'
end
