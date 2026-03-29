# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-03-28

### Added
- `engine.to_h` and `RuleEngine.from_h` for rule configuration serialization
- Composite condition helpers: `all?`, `any?`, `none?` for readable logic
- `engine.stats` for per-rule execution statistics with timing
- Dynamic rule management: `add_rule`, `remove_rule`, `disable_rule`, `enable_rule`
- `engine.chain(*rule_names)` for sequential rule pipelines

## [0.1.2] - 2026-03-24

### Fixed
- Remove inline comments from Development section to match template

## [0.1.1] - 2026-03-22

### Changed
- Expand test coverage

## [0.1.0] - 2026-03-22

### Added
- Initial release
- Declarative rule DSL with condition and action blocks
- Priority-based rule ordering
- All-match mode to run every matching rule
- First-match mode to stop after first match
- Rule evaluation against arbitrary facts
- Results with rule name and action output
