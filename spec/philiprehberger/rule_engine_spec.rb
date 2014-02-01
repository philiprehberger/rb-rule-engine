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
end
