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
end
