# frozen_string_literal: true
require_relative 'lib/tater/version'

Gem::Specification.new do |spec|
  spec.name    = 'tater'
  spec.version = Tater::VERSION
  spec.authors = ['Evan Lecklider']
  spec.email   = ['evan@lecklider.com']

  spec.summary     = 'Minimal internationalization and localization library.'
  spec.description = spec.summary
  spec.homepage    = 'https://github.com/evanleck/tater'
  spec.license     = 'MIT'
  spec.files       = Dir.glob('lib/**/*.rb') + ['README.org', 'LICENSE.txt']
  spec.test_files  = Dir.glob('test/**/*')

  spec.platform                  = Gem::Platform::RUBY
  spec.require_path              = 'lib'
  spec.required_ruby_version     = '>= 2.7.0'
  spec.required_rubygems_version = '>= 2.0'

  spec.metadata['bug_tracker_uri'] = 'https://github.com/evanleck/tater/issues'
  spec.metadata['changelog_uri'] = 'https://github.com/evanleck/tater/blob/main/CHANGELOG.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['source_code_uri'] = 'https://github.com/evanleck/tater'
end
