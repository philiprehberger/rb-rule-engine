# philiprehberger-rule_engine

[![Tests](https://github.com/philiprehberger/rb-rule-engine/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-rule-engine/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-rule_engine.svg)](https://rubygems.org/gems/philiprehberger-rule_engine)
[![License](https://img.shields.io/github/license/philiprehberger/rb-rule-engine)](LICENSE)

Lightweight rule engine with declarative conditions and actions

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-rule_engine"
```

Or install directly:

```bash
gem install philiprehberger-rule_engine
```

## Usage

```ruby
require "philiprehberger/rule_engine"

engine = Philiprehberger::RuleEngine.new do
  rule 'discount' do
    condition { |f| f[:total] > 100 }
    action { |f| f[:total] * 0.9 }
  end

  rule 'free_shipping' do
    condition { |f| f[:total] > 50 }
    action { |_| 'free shipping applied' }
  end
end

results = engine.evaluate({ total: 150 })
# => [{ rule: 'discount', result: 135.0 }, { rule: 'free_shipping', result: 'free shipping applied' }]
```

### Priority

```ruby
engine = Philiprehberger::RuleEngine.new do
  rule 'low' do
    priority 10
    condition { |_| true }
    action { |_| 'runs second' }
  end

  rule 'high' do
    priority 1
    condition { |_| true }
    action { |_| 'runs first' }
  end
end
```

### First-Match Mode

```ruby
engine = Philiprehberger::RuleEngine.new(mode: :first) do
  rule 'premium' do
    priority 1
    condition { |f| f[:tier] == 'premium' }
    action { |_| { discount: 0.20 } }
  end

  rule 'standard' do
    priority 2
    condition { |_| true }
    action { |_| { discount: 0.05 } }
  end
end

results = engine.evaluate({ tier: 'premium' })
# => [{ rule: 'premium', result: { discount: 0.20 } }]
```

## API

### `Engine`

| Method | Description |
|--------|-------------|
| `.new(mode:) { }` | Create engine with rule definitions |
| `#rule(name) { }` | Define a rule with condition and action |
| `#evaluate(facts)` | Evaluate rules against facts |
| `#rules` | Array of registered rules |
| `#mode` | Current evaluation mode |

### Rule DSL

| Method | Description |
|--------|-------------|
| `condition { \|facts\| }` | Set the match condition |
| `action { \|facts\| }` | Set the action to execute |
| `priority(n)` | Set priority (lower runs first) |

## Development

```bash
bundle install
bundle exec rspec      # Run tests
bundle exec rubocop    # Check code style
```

## License

MIT
