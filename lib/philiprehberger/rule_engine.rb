# frozen_string_literal: true

require_relative 'rule_engine/version'
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
  end
end
