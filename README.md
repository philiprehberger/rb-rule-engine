# philiprehberger-rule_engine

[![Tests](https://github.com/philiprehberger/rb-rule-engine/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-rule-engine/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-rule_engine.svg)](https://rubygems.org/gems/philiprehberger-rule_engine)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-rule-engine)](https://github.com/philiprehberger/rb-rule-engine/commits/main)

Lightweight rule engine with declarative conditions and actions

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem 'philiprehberger-rule_engine'
```

Or install directly:

```bash
gem install philiprehberger-rule_engine
```

## Usage

```ruby
require 'philiprehberger/rule_engine'

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

### Composite Conditions

```ruby
engine = Philiprehberger::RuleEngine.new do
  rule 'access' do
    condition { |f| all?(f[:active], any?(f[:admin], f[:moderator])) }
    action { |_| 'granted' }
  end

  rule 'blocked' do
    condition { |f| none?(f[:verified], f[:trusted]) }
    action { |_| 'denied' }
  end
end
```

### Dynamic Rule Management

```ruby
engine = Philiprehberger::RuleEngine.new

engine.add_rule('dynamic') do
  condition { |f| f[:ready] }
  action { |_| 'go' }
end

engine.disable_rule('dynamic')
engine.evaluate({ ready: true })  # => []

engine.enable_rule('dynamic')
engine.evaluate({ ready: true })  # => [{ rule: 'dynamic', result: 'go' }]

engine.remove_rule('dynamic')
```

### Rule Chaining

```ruby
engine = Philiprehberger::RuleEngine.new do
  rule 'fetch' do
    action { |_| 10 }
  end

  rule 'double' do
    action { |f| f[:input] * 2 }
  end

  rule 'format' do
    action { |f| "Result: #{f[:input]}" }
  end
end

engine.chain('fetch', 'double', 'format')
# => 'Result: 20'
```

### Execution Statistics

```ruby
engine = Philiprehberger::RuleEngine.new do
  rule 'tracked' do
    condition { |_| true }
    action { |_| 'ok' }
  end
end

3.times { engine.evaluate({}) }

engine.stats
# => { 'tracked' => { evaluations: 3, matches: 3, executions: 3, avg_time: 0.00001, last_triggered: <Time> } }

engine.reset_stats!
```

### Serialization

```ruby
engine = Philiprehberger::RuleEngine.new(mode: :first) do
  rule 'alpha' do
    priority 1
    condition { |_| true }
    action { |_| 'go' }
  end
end

data = engine.to_h
# => { mode: :first, rules: [{ name: 'alpha', priority: 1, enabled: true }] }

restored = Philiprehberger::RuleEngine.from_h(data) do |r|
  r.condition { |_| true }
  r.action { |_| 'restored' }
end
```

## API

### `Engine`

| Method | Description |
|--------|-------------|
| `.new(mode:) { }` | Create engine with rule definitions |
| `.from_h(data, &resolver)` | Reconstruct engine from serialized hash |
| `#rule(name) { }` | Define a rule with condition and action |
| `#evaluate(facts)` | Evaluate rules against facts |
| `#rules` | Array of registered rules |
| `#mode` | Current evaluation mode |
| `#to_h` | Serialize engine configuration to hash |
| `#add_rule(name) { }` | Add a rule after engine creation |
| `#remove_rule(name)` | Remove a rule by name |
| `#disable_rule(name)` | Disable a rule (skipped during evaluation) |
| `#enable_rule(name)` | Re-enable a disabled rule |
| `#chain(*rule_names)` | Execute rules sequentially as a pipeline |
| `#stats` | Per-rule execution statistics |
| `#reset_stats!` | Clear all execution statistics |

### Rule DSL

| Method | Description |
|--------|-------------|
| `condition { \|facts\| }` | Set the match condition |
| `action { \|facts\| }` | Set the action to execute |
| `priority(n)` | Set priority (lower runs first) |

### Composite Condition Helpers

| Method | Description |
|--------|-------------|
| `all?(*conditions)` | True if all conditions are truthy |
| `any?(*conditions)` | True if any condition is truthy |
| `none?(*conditions)` | True if no conditions are truthy |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-rule-engine)

🐛 [Report issues](https://github.com/philiprehberger/rb-rule-engine/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-rule-engine/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
