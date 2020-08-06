# frozen_string_literal: true
Gem::Specification.new do |spec|
  spec.name    = 'tater'
  spec.version = '1.3.2'
  spec.authors = ['Evan Lecklider']
  spec.email   = ['evan@lecklider.com']

  spec.summary     = 'Minimal internationalization and localization library.'
  spec.description = spec.summary
  spec.homepage    = 'https://github.com/evanleck/tater'
  spec.license     = 'MIT'
  spec.files       = ['lib/tater.rb', 'README.md', 'LICENSE.txt']
  spec.test_files  = Dir.glob('test/**/*')

  spec.platform                  = Gem::Platform::RUBY
  spec.require_path              = 'lib'
  spec.required_ruby_version     = '>= 2.5.0'
  spec.required_rubygems_version = '>= 2.0'

  spec.metadata = {
    'bug_tracker_uri' => 'https://github.com/evanleck/tater/issues',
    'source_code_uri' => 'https://github.com/evanleck/tater'
  }

  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-performance'
end
