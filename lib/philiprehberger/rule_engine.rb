# frozen_string_literal: true

require_relative 'rule_engine/version'
require_relative 'rule_engine/helpers'
require_relative 'rule_engine/rule'
require_relative 'rule_engine/engine'

module Philiprehberger
  module RuleEngine
    class Error < StandardError; end

    # Create a new rule engine.
    #
    # @param mode [Symbol] :all to run all matching rules, :first to stop after first match
    # @yield [engine] block for defining rules using the DSL
    # @return [Engine] the configured engine
    def self.new(mode: :all, &block)
      Engine.new(mode: mode, &block)
    end

    # Reconstruct an engine from a serialized hash.
    # The resolver block maps rule names to condition/action implementations.
    #
    # @param data [Hash] serialized engine data from Engine#to_h
    # @yield [name] block that receives a rule name and should configure the rule
    # @return [Engine] the reconstructed engine
    def self.from_h(data, &resolver)
      raise Error, 'resolver block is required' unless resolver

      mode = (data[:mode] || data['mode'] || :all).to_sym
      engine = Engine.new(mode: mode)

      rules = data[:rules] || data['rules'] || []
      rules.each do |rule_data|
        name = rule_data[:name] || rule_data['name']
        priority_val = rule_data[:priority] || rule_data['priority'] || 0
        enabled_val = rule_data.key?(:enabled) ? rule_data[:enabled] : rule_data.fetch('enabled', true)

        r = engine.add_rule(name) do
          priority priority_val
        end
        r.enabled = enabled_val
        resolver.call(r)
      end

      engine
    end
  end
end
