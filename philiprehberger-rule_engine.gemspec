# frozen_string_literal: true

require_relative 'lib/philiprehberger/rule_engine/version'

Gem::Specification.new do |spec|
  spec.name = 'philiprehberger-rule_engine'
  spec.version = Philiprehberger::RuleEngine::VERSION
  spec.authors = ['Philip Rehberger']
  spec.email = ['me@philiprehberger.com']

  spec.summary = 'Lightweight rule engine with declarative conditions and actions'
  spec.description = 'A lightweight rule engine with a declarative DSL for defining conditions and actions. ' \
                     'Supports priority-based ordering, rule tagging with selective evaluation, ' \
                     'first-match and all-match modes, dry run, conflict detection, serialization, ' \
                     'chaining, and per-rule execution statistics.'
  spec.homepage = 'https://philiprehberger.com/open-source-packages/ruby/philiprehberger-rule_engine'
  spec.license = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/philiprehberger/rb-rule-engine'
  spec.metadata['changelog_uri'] = 'https://github.com/philiprehberger/rb-rule-engine/blob/main/CHANGELOG.md'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/philiprehberger/rb-rule-engine/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
