# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::RuleEngine do
  describe 'VERSION' do
    it 'has a version number' do
      expect(Philiprehberger::RuleEngine::VERSION).not_to be_nil
    end
  end

  describe '.new' do
    it 'creates an engine with the DSL block' do
      engine = described_class.new do
        rule 'test' do
          condition { |f| f[:value] > 0 }
          action { |f| f[:value] * 2 }
        end
      end

      expect(engine.rules.size).to eq(1)
      expect(engine.rules.first.name).to eq('test')
    end

    it 'defaults to all-match mode' do
      engine = described_class.new
      expect(engine.mode).to eq(:all)
    end
  end

  describe '.from_h' do
    it 'reconstructs an engine from serialized data' do
      data = {
        mode: :first,
        rules: [
          { name: 'rule_a', priority: 1, enabled: true },
          { name: 'rule_b', priority: 2, enabled: false }
        ]
      }

      engine = described_class.from_h(data) do |r|
        case r.name
        when 'rule_a'
          r.condition { |_| true }
          r.action { |_| 'a_result' }
        when 'rule_b'
          r.condition { |_| true }
          r.action { |_| 'b_result' }
        end
      end

      expect(engine.mode).to eq(:first)
      expect(engine.rules.size).to eq(2)
      expect(engine.rules[0].name).to eq('rule_a')
      expect(engine.rules[0].priority).to eq(1)
      expect(engine.rules[0].enabled).to be true
      expect(engine.rules[1].name).to eq('rule_b')
      expect(engine.rules[1].enabled).to be false
    end

    it 'raises without a resolver block' do
      expect { described_class.from_h({}) }
        .to raise_error(Philiprehberger::RuleEngine::Error, /resolver/)
    end

    it 'handles string keys in data' do
      data = {
        'mode' => 'all',
        'rules' => [
          { 'name' => 'test', 'priority' => 5, 'enabled' => true }
        ]
      }

      engine = described_class.from_h(data) do |r|
        r.condition { |_| true }
        r.action { |_| 'ok' }
      end

      expect(engine.mode).to eq(:all)
      expect(engine.rules.first.priority).to eq(5)
    end

    it 'roundtrips with to_h' do
      original = described_class.new(mode: :first) do
        rule 'alpha' do
          priority 3
          condition { |_| true }
          action { |_| 'alpha' }
        end
      end

      data = original.to_h

      restored = described_class.from_h(data) do |r|
        r.condition { |_| true }
        r.action { |_| "#{r.name}_restored" }
      end

      expect(restored.mode).to eq(:first)
      expect(restored.rules.first.name).to eq('alpha')
      expect(restored.rules.first.priority).to eq(3)
    end
  end
end

RSpec.describe Philiprehberger::RuleEngine::Engine do
  describe '#evaluate with all-match mode' do
    it 'runs all matching rules' do
      engine = described_class.new(mode: :all) do
        rule 'double' do
          condition { |f| f[:value] > 0 }
          action { |f| f[:value] * 2 }
        end

        rule 'triple' do
          condition { |f| f[:value] > 5 }
          action { |f| f[:value] * 3 }
        end
      end

      results = engine.evaluate({ value: 10 })
      expect(results.size).to eq(2)
      expect(results[0]).to eq({ rule: 'double', result: 20 })
      expect(results[1]).to eq({ rule: 'triple', result: 30 })
    end

    it 'skips non-matching rules' do
      engine = described_class.new do
        rule 'low' do
          condition { |f| f[:value] < 5 }
          action { |_| 'low' }
        end

        rule 'high' do
          condition { |f| f[:value] >= 5 }
          action { |_| 'high' }
        end
      end

      results = engine.evaluate({ value: 10 })
      expect(results.size).to eq(1)
      expect(results[0][:rule]).to eq('high')
    end

    it 'returns empty array when no rules match' do
      engine = described_class.new do
        rule 'never' do
          condition { |_| false }
          action { |_| 'nope' }
        end
      end

      expect(engine.evaluate({})).to be_empty
    end
  end

  describe '#evaluate with first-match mode' do
    it 'stops after first matching rule' do
      engine = described_class.new(mode: :first) do
        rule 'first' do
          condition { |_| true }
          action { |_| 'first' }
        end

        rule 'second' do
          condition { |_| true }
          action { |_| 'second' }
        end
      end

      results = engine.evaluate({})
      expect(results.size).to eq(1)
      expect(results[0][:rule]).to eq('first')
    end
  end

  describe 'priority' do
    it 'executes rules in priority order' do
      engine = described_class.new(mode: :first) do
        rule 'low_priority' do
          priority 10
          condition { |_| true }
          action { |_| 'low' }
        end

        rule 'high_priority' do
          priority 1
          condition { |_| true }
          action { |_| 'high' }
        end
      end

      results = engine.evaluate({})
      expect(results[0][:rule]).to eq('high_priority')
    end

    it 'defaults priority to 0' do
      engine = described_class.new do
        rule 'default' do
          condition { |_| true }
          action { |_| 'ok' }
        end
      end

      expect(engine.rules.first.priority).to eq(0)
    end
  end

  describe 'invalid mode' do
    it 'raises on invalid mode' do
      expect { described_class.new(mode: :invalid) }
        .to raise_error(Philiprehberger::RuleEngine::Error, /mode/)
    end
  end

  describe 'rules without conditions or actions' do
    it 'handles rule with no condition' do
      engine = described_class.new do
        rule 'no_condition' do
          action { |_| 'result' }
        end
      end

      expect(engine.evaluate({})).to be_empty
    end

    it 'handles rule with no action' do
      engine = described_class.new do
        rule 'no_action' do
          condition { |_| true }
        end
      end

      results = engine.evaluate({})
      expect(results.size).to eq(1)
      expect(results[0][:result]).to be_nil
    end
  end

  # --- Expanded tests ---

  describe 'empty engine' do
    it 'returns empty array with no rules' do
      engine = described_class.new
      expect(engine.evaluate({ anything: true })).to eq([])
    end

    it 'has empty rules array' do
      engine = described_class.new
      expect(engine.rules).to eq([])
    end
  end

  describe 'priority ordering in all-match mode' do
    it 'returns results in priority order' do
      engine = described_class.new(mode: :all) do
        rule 'c_last' do
          priority 30
          condition { |_| true }
          action { |_| 'c' }
        end

        rule 'a_first' do
          priority 10
          condition { |_| true }
          action { |_| 'a' }
        end

        rule 'b_middle' do
          priority 20
          condition { |_| true }
          action { |_| 'b' }
        end
      end

      results = engine.evaluate({})
      expect(results.map { |r| r[:result] }).to eq(%w[a b c])
    end
  end

  describe 'rules with same priority' do
    it 'preserves insertion order for same priority' do
      engine = described_class.new(mode: :all) do
        rule 'first_added' do
          priority 0
          condition { |_| true }
          action { |_| 'first' }
        end

        rule 'second_added' do
          priority 0
          condition { |_| true }
          action { |_| 'second' }
        end
      end

      results = engine.evaluate({})
      expect(results.size).to eq(2)
    end
  end

  describe 'first-match with priority' do
    it 'returns only the highest priority matching rule' do
      engine = described_class.new(mode: :first) do
        rule 'low' do
          priority 100
          condition { |_| true }
          action { |_| 'low_priority' }
        end

        rule 'high' do
          priority 1
          condition { |_| true }
          action { |_| 'high_priority' }
        end

        rule 'medium' do
          priority 50
          condition { |_| true }
          action { |_| 'medium_priority' }
        end
      end

      results = engine.evaluate({})
      expect(results.size).to eq(1)
      expect(results[0][:result]).to eq('high_priority')
    end
  end

  describe 'first-match skips non-matching high-priority rules' do
    it 'selects the first matching rule by priority' do
      engine = described_class.new(mode: :first) do
        rule 'highest_no_match' do
          priority 1
          condition { |_| false }
          action { |_| 'never' }
        end

        rule 'second_matches' do
          priority 2
          condition { |_| true }
          action { |_| 'found' }
        end
      end

      results = engine.evaluate({})
      expect(results.size).to eq(1)
      expect(results[0][:result]).to eq('found')
    end
  end

  describe 'multiple actions per evaluation' do
    it 'collects results from all matching rules' do
      engine = described_class.new(mode: :all) do
        rule 'add_discount' do
          condition { |f| f[:total] > 100 }
          action { |f| { discount: f[:total] * 0.1 } }
        end

        rule 'add_shipping' do
          condition { |f| f[:total] > 0 }
          action { |_| { shipping: 5.99 } }
        end

        rule 'add_tax' do
          condition { |f| f[:total] > 0 }
          action { |f| { tax: f[:total] * 0.08 } }
        end
      end

      results = engine.evaluate({ total: 150 })
      expect(results.size).to eq(3)
      expect(results.map { |r| r[:result] }).to include(
        { discount: 15.0 },
        { shipping: 5.99 },
        { tax: 12.0 }
      )
    end
  end

  describe 'complex condition logic' do
    it 'supports multi-field conditions' do
      engine = described_class.new do
        rule 'complex' do
          condition { |f| f[:age] >= 18 && f[:country] == 'US' && f[:verified] }
          action { |_| 'approved' }
        end
      end

      expect(engine.evaluate({ age: 21, country: 'US', verified: true }).size).to eq(1)
      expect(engine.evaluate({ age: 16, country: 'US', verified: true })).to be_empty
      expect(engine.evaluate({ age: 21, country: 'UK', verified: true })).to be_empty
    end
  end

  describe 'engine without block' do
    it 'creates engine and adds rules later' do
      engine = described_class.new
      engine.rule('late_rule') do
        condition { |_| true }
        action { |_| 'added_later' }
      end

      results = engine.evaluate({})
      expect(results.size).to eq(1)
      expect(results[0][:result]).to eq('added_later')
    end
  end

  describe 'rule returns the created rule' do
    it 'returns a Rule object from #rule' do
      engine = described_class.new
      result = engine.rule('my_rule') do
        condition { |_| true }
        action { |_| 'ok' }
      end
      expect(result).to be_a(Philiprehberger::RuleEngine::Rule)
      expect(result.name).to eq('my_rule')
    end
  end

  # --- Serialization (to_h) ---

  describe '#to_h' do
    it 'serializes engine configuration' do
      engine = described_class.new(mode: :first) do
        rule 'alpha' do
          priority 5
          condition { |_| true }
          action { |_| 'go' }
        end

        rule 'beta' do
          priority 10
          condition { |_| true }
          action { |_| 'stop' }
        end
      end

      data = engine.to_h
      expect(data[:mode]).to eq(:first)
      expect(data[:rules].size).to eq(2)
      expect(data[:rules][0]).to eq({ name: 'alpha', priority: 5, enabled: true, tags: [] })
      expect(data[:rules][1]).to eq({ name: 'beta', priority: 10, enabled: true, tags: [] })
    end

    it 'includes disabled state in serialization' do
      engine = described_class.new do
        rule 'active' do
          condition { |_| true }
          action { |_| 'yes' }
        end
      end
      engine.disable_rule('active')

      data = engine.to_h
      expect(data[:rules][0][:enabled]).to be false
    end
  end

  # --- Composite conditions (Helpers) ---

  describe 'composite condition helpers' do
    describe 'all?' do
      it 'returns true when all conditions are truthy' do
        engine = described_class.new do
          rule 'all_true' do
            condition { |f| all?(f[:a], f[:b], f[:c]) }
            action { |_| 'passed' }
          end
        end

        results = engine.evaluate({ a: true, b: true, c: true })
        expect(results.size).to eq(1)
      end

      it 'returns false when any condition is falsy' do
        engine = described_class.new do
          rule 'not_all' do
            condition { |f| all?(f[:a], f[:b], f[:c]) }
            action { |_| 'passed' }
          end
        end

        results = engine.evaluate({ a: true, b: false, c: true })
        expect(results).to be_empty
      end

      it 'supports proc arguments' do
        engine = described_class.new do
          rule 'proc_all' do
            condition { |f| all?(-> { f[:x] > 0 }, -> { f[:y] > 0 }) }
            action { |_| 'ok' }
          end
        end

        expect(engine.evaluate({ x: 1, y: 2 }).size).to eq(1)
        expect(engine.evaluate({ x: 1, y: -1 })).to be_empty
      end
    end

    describe 'any?' do
      it 'returns true when at least one condition is truthy' do
        engine = described_class.new do
          rule 'any_true' do
            condition { |f| any?(f[:a], f[:b]) }
            action { |_| 'passed' }
          end
        end

        results = engine.evaluate({ a: false, b: true })
        expect(results.size).to eq(1)
      end

      it 'returns false when all conditions are falsy' do
        engine = described_class.new do
          rule 'none_true' do
            condition { |f| any?(f[:a], f[:b]) }
            action { |_| 'passed' }
          end
        end

        results = engine.evaluate({ a: false, b: false })
        expect(results).to be_empty
      end

      it 'supports proc arguments' do
        engine = described_class.new do
          rule 'proc_any' do
            condition { |f| any?(-> { f[:x] > 10 }, -> { f[:y] > 10 }) }
            action { |_| 'ok' }
          end
        end

        expect(engine.evaluate({ x: 1, y: 20 }).size).to eq(1)
        expect(engine.evaluate({ x: 1, y: 2 })).to be_empty
      end
    end

    describe 'none?' do
      it 'returns true when no conditions are truthy' do
        engine = described_class.new do
          rule 'none_match' do
            condition { |f| none?(f[:a], f[:b]) }
            action { |_| 'passed' }
          end
        end

        results = engine.evaluate({ a: false, b: false })
        expect(results.size).to eq(1)
      end

      it 'returns false when any condition is truthy' do
        engine = described_class.new do
          rule 'some_match' do
            condition { |f| none?(f[:a], f[:b]) }
            action { |_| 'passed' }
          end
        end

        results = engine.evaluate({ a: false, b: true })
        expect(results).to be_empty
      end

      it 'supports proc arguments' do
        engine = described_class.new do
          rule 'proc_none' do
            condition { |f| none?(-> { f[:x] > 100 }, -> { f[:y] > 100 }) }
            action { |_| 'ok' }
          end
        end

        expect(engine.evaluate({ x: 1, y: 2 }).size).to eq(1)
        expect(engine.evaluate({ x: 200, y: 2 })).to be_empty
      end
    end

    describe 'nested composite conditions' do
      it 'supports combining all? and any?' do
        engine = described_class.new do
          rule 'nested' do
            condition { |f| all?(f[:active], any?(f[:admin], f[:moderator])) }
            action { |_| 'access_granted' }
          end
        end

        expect(engine.evaluate({ active: true, admin: false, moderator: true }).size).to eq(1)
        expect(engine.evaluate({ active: false, admin: true, moderator: true })).to be_empty
        expect(engine.evaluate({ active: true, admin: false, moderator: false })).to be_empty
      end
    end
  end

  # --- Execution statistics ---

  describe '#stats' do
    it 'tracks evaluations, matches, and executions' do
      engine = described_class.new do
        rule 'always' do
          condition { |_| true }
          action { |_| 'ok' }
        end

        rule 'never' do
          condition { |_| false }
          action { |_| 'nope' }
        end
      end

      3.times { engine.evaluate({}) }
      stats = engine.stats

      expect(stats['always'][:evaluations]).to eq(3)
      expect(stats['always'][:matches]).to eq(3)
      expect(stats['always'][:executions]).to eq(3)
      expect(stats['always'][:avg_time]).to be_a(Float)
      expect(stats['always'][:last_triggered]).to be_a(Time)

      expect(stats['never'][:evaluations]).to eq(3)
      expect(stats['never'][:matches]).to eq(0)
      expect(stats['never'][:executions]).to eq(0)
      expect(stats['never'][:last_triggered]).to be_nil
    end

    it 'returns empty stats for new rules' do
      engine = described_class.new do
        rule 'fresh' do
          condition { |_| true }
          action { |_| 'ok' }
        end
      end

      stats = engine.stats
      expect(stats['fresh'][:evaluations]).to eq(0)
      expect(stats['fresh'][:matches]).to eq(0)
      expect(stats['fresh'][:executions]).to eq(0)
      expect(stats['fresh'][:avg_time]).to eq(0.0)
      expect(stats['fresh'][:last_triggered]).to be_nil
    end
  end

  describe '#reset_stats!' do
    it 'clears all statistics' do
      engine = described_class.new do
        rule 'tracked' do
          condition { |_| true }
          action { |_| 'ok' }
        end
      end

      engine.evaluate({})
      expect(engine.stats['tracked'][:evaluations]).to eq(1)

      engine.reset_stats!

      stats = engine.stats
      expect(stats['tracked'][:evaluations]).to eq(0)
      expect(stats['tracked'][:matches]).to eq(0)
      expect(stats['tracked'][:executions]).to eq(0)
      expect(stats['tracked'][:last_triggered]).to be_nil
    end
  end

  # --- Dynamic rule management ---

  describe '#add_rule' do
    it 'adds a rule after engine creation' do
      engine = described_class.new
      engine.add_rule('dynamic') do
        condition { |f| f[:ready] }
        action { |_| 'added' }
      end

      expect(engine.rules.size).to eq(1)
      results = engine.evaluate({ ready: true })
      expect(results.size).to eq(1)
      expect(results[0][:result]).to eq('added')
    end

    it 'returns the created rule' do
      engine = described_class.new
      r = engine.add_rule('test') do
        condition { |_| true }
        action { |_| 'ok' }
      end
      expect(r).to be_a(Philiprehberger::RuleEngine::Rule)
      expect(r.name).to eq('test')
    end
  end

  describe '#remove_rule' do
    it 'removes a rule by name' do
      engine = described_class.new do
        rule 'keep' do
          condition { |_| true }
          action { |_| 'kept' }
        end

        rule 'remove_me' do
          condition { |_| true }
          action { |_| 'gone' }
        end
      end

      removed = engine.remove_rule('remove_me')
      expect(removed.name).to eq('remove_me')
      expect(engine.rules.size).to eq(1)
      expect(engine.rules.first.name).to eq('keep')
    end

    it 'returns nil when rule not found' do
      engine = described_class.new
      expect(engine.remove_rule('nonexistent')).to be_nil
    end

    it 'removes stats for the removed rule' do
      engine = described_class.new do
        rule 'tracked' do
          condition { |_| true }
          action { |_| 'ok' }
        end
      end

      engine.evaluate({})
      engine.remove_rule('tracked')
      expect(engine.stats).not_to have_key('tracked')
    end
  end

  describe '#clear_rules!' do
    it 'clears all registered rules' do
      engine = described_class.new do
        rule 'one' do
          condition { |_| true }
          action { |_| 'a' }
        end

        rule 'two' do
          condition { |_| true }
          action { |_| 'b' }
        end
      end

      engine.clear_rules!
      expect(engine.rules).to be_empty
    end

    it 'clears statistics for all rules' do
      engine = described_class.new do
        rule 'tracked' do
          condition { |_| true }
          action { |_| 'ok' }
        end
      end

      engine.evaluate({})
      expect(engine.stats).not_to be_empty

      engine.clear_rules!
      expect(engine.stats).to eq({})
    end

    it 'returns the engine for chaining' do
      engine = described_class.new do
        rule 'noop' do
          condition { |_| true }
          action { |_| 'ok' }
        end
      end

      expect(engine.clear_rules!).to be(engine)
    end
  end

  describe '#rule_names' do
    it 'returns an empty array when no rules are registered' do
      engine = described_class.new
      expect(engine.rule_names).to eq([])
    end

    it 'returns rule names in declaration order' do
      engine = described_class.new do
        rule 'alpha' do
          condition { |_| true }
          action { |_| 'a' }
        end

        rule 'beta' do
          condition { |_| true }
          action { |_| 'b' }
        end

        rule 'gamma' do
          condition { |_| true }
          action { |_| 'g' }
        end
      end

      expect(engine.rule_names).to eq(%w[alpha beta gamma])
    end
  end

  describe '#disable_rule / #enable_rule' do
    it 'disables a rule so it is skipped during evaluation' do
      engine = described_class.new do
        rule 'skippable' do
          condition { |_| true }
          action { |_| 'should_skip' }
        end

        rule 'active' do
          condition { |_| true }
          action { |_| 'should_run' }
        end
      end

      engine.disable_rule('skippable')
      results = engine.evaluate({})
      expect(results.size).to eq(1)
      expect(results[0][:rule]).to eq('active')
    end

    it 're-enables a disabled rule' do
      engine = described_class.new do
        rule 'toggled' do
          condition { |_| true }
          action { |_| 'back' }
        end
      end

      engine.disable_rule('toggled')
      expect(engine.evaluate({})).to be_empty

      engine.enable_rule('toggled')
      results = engine.evaluate({})
      expect(results.size).to eq(1)
      expect(results[0][:result]).to eq('back')
    end

    it 'raises when disabling a nonexistent rule' do
      engine = described_class.new
      expect { engine.disable_rule('missing') }
        .to raise_error(Philiprehberger::RuleEngine::Error, /rule not found/)
    end

    it 'raises when enabling a nonexistent rule' do
      engine = described_class.new
      expect { engine.enable_rule('missing') }
        .to raise_error(Philiprehberger::RuleEngine::Error, /rule not found/)
    end

    it 'reflects disabled state in enabled accessor' do
      engine = described_class.new do
        rule 'check' do
          condition { |_| true }
          action { |_| 'ok' }
        end
      end

      expect(engine.rules.first.enabled).to be true
      engine.disable_rule('check')
      expect(engine.rules.first.enabled).to be false
    end
  end

  # --- Rule chaining ---

  describe '#chain' do
    it 'executes rules sequentially passing results as input' do
      engine = described_class.new do
        rule 'start' do
          condition { |_| true }
          action { |_| 10 }
        end

        rule 'double' do
          condition { |_| true }
          action { |f| f[:input] * 2 }
        end

        rule 'add_five' do
          condition { |_| true }
          action { |f| f[:input] + 5 }
        end
      end

      result = engine.chain('start', 'double', 'add_five')
      expect(result).to eq(25)
    end

    it 'passes nil as input to the first rule' do
      engine = described_class.new do
        rule 'first' do
          condition { |_| true }
          action { |f| f[:input] }
        end
      end

      result = engine.chain('first')
      expect(result).to be_nil
    end

    it 'raises when a rule name does not exist' do
      engine = described_class.new
      expect { engine.chain('nonexistent') }
        .to raise_error(Philiprehberger::RuleEngine::Error, /rule not found/)
    end

    it 'handles string transformations in chain' do
      engine = described_class.new do
        rule 'greet' do
          condition { |_| true }
          action { |_| 'hello' }
        end

        rule 'upcase' do
          condition { |_| true }
          action { |f| f[:input].upcase }
        end

        rule 'exclaim' do
          condition { |_| true }
          action { |f| "#{f[:input]}!" }
        end
      end

      result = engine.chain('greet', 'upcase', 'exclaim')
      expect(result).to eq('HELLO!')
    end

    it 'works with a single rule' do
      engine = described_class.new do
        rule 'solo' do
          condition { |_| true }
          action { |_| 42 }
        end
      end

      expect(engine.chain('solo')).to eq(42)
    end
  end

  describe '#dry_run' do
    it 'returns matched rules without executing actions' do
      engine = described_class.new
      executed = false
      engine.rule('test') do |r|
        r.priority 10
        r.condition { |facts| facts[:value] > 5 }
        r.action { |_facts| executed = true }
      end

      result = engine.dry_run({ value: 10 })
      expect(result.length).to eq(1)
      expect(result[0][:name]).to eq('test')
      expect(executed).to be false
    end

    it 'returns empty array when no rules match' do
      engine = described_class.new
      engine.rule('test') do |r|
        r.condition { |facts| facts[:value] > 100 }
        r.action { |_| nil }
      end

      expect(engine.dry_run({ value: 1 })).to be_empty
    end

    it 'respects :first mode' do
      engine = described_class.new(mode: :first)
      engine.rule('a') do |r|
        r.priority 10
        r.condition { |_| true }
        r.action { |_| nil }
      end
      engine.rule('b') do |r|
        r.priority 5
        r.condition { |_| true }
        r.action { |_| nil }
      end

      result = engine.dry_run({})
      expect(result.length).to eq(1)
    end
  end

  describe '#detect_conflicts' do
    it 'returns pairs of enabled rules' do
      engine = described_class.new
      engine.rule('a') do |r|
        r.condition { |_| true }
        r.action { |_| nil }
      end
      engine.rule('b') do |r|
        r.condition { |_| true }
        r.action { |_| nil }
      end

      conflicts = engine.detect_conflicts
      expect(conflicts.length).to eq(1)
      expect(conflicts[0][:rules]).to contain_exactly('a', 'b')
    end

    it 'returns empty for single rule' do
      engine = described_class.new
      engine.rule('only') do |r|
        r.condition { |_| true }
        r.action { |_| nil }
      end

      expect(engine.detect_conflicts).to be_empty
    end
  end

  describe '#validate_rules' do
    it 'returns valid for complete rules' do
      engine = described_class.new
      engine.rule('test') do |r|
        r.condition { |_| true }
        r.action { |_| nil }
      end

      result = engine.validate_rules
      expect(result[:valid]).to be true
    end

    it 'detects missing conditions' do
      engine = described_class.new
      engine.rule('no_cond') do |r|
        r.action { |_| nil }
      end

      result = engine.validate_rules
      expect(result[:valid]).to be false
      expect(result[:issues].first).to include('no condition')
    end

    it 'detects missing actions' do
      engine = described_class.new
      engine.rule('no_act') do |r|
        r.condition { |_| true }
      end

      result = engine.validate_rules
      expect(result[:valid]).to be false
      expect(result[:issues].first).to include('no action')
    end
  end
end

RSpec.describe Philiprehberger::RuleEngine::Rule do
  describe '#matches?' do
    it 'returns true when condition matches' do
      rule = described_class.new('test')
      rule.condition { |f| f[:ok] }
      expect(rule.matches?({ ok: true })).to be true
    end

    it 'returns false when condition does not match' do
      rule = described_class.new('test')
      rule.condition { |f| f[:ok] }
      expect(rule.matches?({ ok: false })).to be false
    end

    it 'returns false when no condition is set' do
      rule = described_class.new('test')
      expect(rule.matches?({})).to be false
    end
  end

  describe '#execute' do
    it 'runs the action block' do
      rule = described_class.new('test')
      rule.action { |f| f[:value] + 1 }
      expect(rule.execute({ value: 5 })).to eq(6)
    end

    it 'returns nil when no action is set' do
      rule = described_class.new('test')
      expect(rule.execute({})).to be_nil
    end
  end

  # --- Expanded tests ---

  describe '#priority' do
    it 'returns 0 by default' do
      rule = described_class.new('test')
      expect(rule.priority).to eq(0)
    end

    it 'sets and returns the priority' do
      rule = described_class.new('test')
      rule.priority(5)
      expect(rule.priority).to eq(5)
    end

    it 'supports negative priority' do
      rule = described_class.new('test')
      rule.priority(-10)
      expect(rule.priority).to eq(-10)
    end
  end

  describe '#name' do
    it 'returns the rule name' do
      rule = described_class.new('my_rule')
      expect(rule.name).to eq('my_rule')
    end
  end

  describe '#matches? coerces to boolean' do
    it 'returns true for truthy non-boolean condition result' do
      rule = described_class.new('test')
      rule.condition { |_| 'truthy string' }
      expect(rule.matches?({})).to be true
    end

    it 'returns false for nil condition result' do
      rule = described_class.new('test')
      rule.condition { |_| nil }
      expect(rule.matches?({})).to be false
    end
  end

  describe '#to_h' do
    it 'serializes rule metadata' do
      rule = described_class.new('my_rule')
      rule.priority(7)
      expect(rule.to_h).to eq({ name: 'my_rule', priority: 7, enabled: true, tags: [] })
    end

    it 'includes disabled state' do
      rule = described_class.new('disabled_rule')
      rule.enabled = false
      expect(rule.to_h[:enabled]).to be false
    end
  end

  describe '#enabled' do
    it 'defaults to true' do
      rule = described_class.new('test')
      expect(rule.enabled).to be true
    end

    it 'can be toggled' do
      rule = described_class.new('test')
      rule.enabled = false
      expect(rule.enabled).to be false
      rule.enabled = true
      expect(rule.enabled).to be true
    end
  end
end

RSpec.describe Philiprehberger::RuleEngine::Helpers do
  let(:helper) do
    Class.new { include Philiprehberger::RuleEngine::Helpers }.new
  end

  describe '#all?' do
    it 'returns true when all values are truthy' do
      expect(helper.all?(true, 1, 'yes')).to be true
    end

    it 'returns false when any value is falsy' do
      expect(helper.all?(true, nil, 'yes')).to be false
    end

    it 'evaluates procs' do
      expect(helper.all?(-> { true }, -> { 1 })).to be true
      expect(helper.all?(-> { true }, -> {})).to be false
    end

    it 'returns true with no arguments' do
      expect(helper.all?).to be true
    end
  end

  describe '#any?' do
    it 'returns true when at least one value is truthy' do
      expect(helper.any?(false, nil, 'yes')).to be true
    end

    it 'returns false when all values are falsy' do
      expect(helper.any?(false, nil)).to be false
    end

    it 'evaluates procs' do
      expect(helper.any?(-> { false }, -> { 42 })).to be true
      expect(helper.any?(-> { false }, -> {})).to be false
    end

    it 'returns false with no arguments' do
      expect(helper.any?).to be false
    end
  end

  describe '#none?' do
    it 'returns true when no values are truthy' do
      expect(helper.none?(false, nil)).to be true
    end

    it 'returns false when any value is truthy' do
      expect(helper.none?(false, true)).to be false
    end

    it 'evaluates procs' do
      expect(helper.none?(-> { false }, -> {})).to be true
      expect(helper.none?(-> { false }, -> { 1 })).to be false
    end

    it 'returns true with no arguments' do
      expect(helper.none?).to be true
    end
  end
end

RSpec.describe 'Rule tagging' do
  let(:engine) do
    Philiprehberger::RuleEngine.new do
      rule 'validate', tags: [:validation] do
        condition { |f| f[:age] && f[:age] >= 18 }
        action { |_| 'valid' }
      end
      rule 'discount', tags: [:pricing] do
        condition { |f| f[:premium] }
        action { |_| 'discount applied' }
      end
      rule 'log_access', tags: %i[validation logging] do
        condition { |_| true }
        action { |_| 'logged' }
      end
    end
  end

  describe '#rules_by_tag' do
    it 'returns rules matching the tag' do
      names = engine.rules_by_tag(:validation).map(&:name)
      expect(names).to contain_exactly('validate', 'log_access')
    end

    it 'returns empty array for unknown tag' do
      expect(engine.rules_by_tag(:unknown)).to be_empty
    end
  end

  describe '#evaluate with tags:' do
    it 'only runs rules with matching tags' do
      results = engine.evaluate({ age: 20, premium: true }, tags: [:pricing])
      expect(results.length).to eq(1)
      expect(results.first[:rule]).to eq('discount')
    end

    it 'runs all rules when tags is nil' do
      results = engine.evaluate({ age: 20, premium: true })
      expect(results.length).to eq(3)
    end

    it 'supports multiple tags (OR logic)' do
      results = engine.evaluate({ age: 20, premium: true }, tags: %i[validation pricing])
      expect(results.length).to eq(3)
    end
  end

  describe '#dry_run with tags:' do
    it 'filters by tag' do
      matched = engine.dry_run({ age: 20 }, tags: [:validation])
      names = matched.map { |m| m[:name] }
      expect(names).to contain_exactly('validate', 'log_access')
    end
  end

  describe 'Rule#tags' do
    it 'stores tags as symbols' do
      rule = engine.rules.find { |r| r.name == 'validate' }
      expect(rule.tags).to eq([:validation])
    end

    it 'defaults to empty array' do
      e = Philiprehberger::RuleEngine.new do
        rule 'no_tags' do
          condition { |_| true }
          action { |_| 'ok' }
        end
      end
      expect(e.rules.first.tags).to eq([])
    end
  end

  describe 'serialization with tags' do
    it 'includes tags in to_h' do
      data = engine.to_h
      validate_rule = data[:rules].find { |r| r[:name] == 'validate' }
      expect(validate_rule[:tags]).to eq([:validation])
    end

    it 'restores tags from from_h' do
      data = engine.to_h
      restored = Philiprehberger::RuleEngine.from_h(data) do |r|
        r.condition { |_| true }
        r.action { |_| 'restored' }
      end
      rule = restored.rules.find { |r| r.name == 'validate' }
      expect(rule.tags).to eq([:validation])
    end
  end
end
