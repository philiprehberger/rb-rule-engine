# frozen_string_literal: true

module Philiprehberger
  module RuleEngine
    # A single rule with a name, condition, action, and priority.
    class Rule
      # @return [String] the rule name
      attr_reader :name

      # @param name [String] the rule name
      def initialize(name)
        @name = name
        @priority = 0
        @condition = nil
        @action = nil
      end

      # Set the condition for this rule.
      #
      # @yield [facts] block that receives facts and returns truthy/falsy
      # @return [void]
      def condition(&block)
        @condition = block
      end

      # Set the action for this rule.
      #
      # @yield [facts] block that receives facts and performs the action
      # @return [void]
      def action(&block)
        @action = block
      end

      # Get or set the priority for this rule.
      #
      # @param value [Integer, nil] priority value (lower runs first); omit to get current value
      # @return [Integer] the current priority
      def priority(value = nil)
        if value.nil?
          @priority
        else
          @priority = value
        end
      end

      # Check if the condition matches the given facts.
      #
      # @param facts [Object] the facts to evaluate
      # @return [Boolean]
      def matches?(facts)
        return false unless @condition

        !!@condition.call(facts)
      end

      # Execute the action with the given facts.
      #
      # @param facts [Object] the facts to act on
      # @return [Object] the action result
      def execute(facts)
        return nil unless @action

        @action.call(facts)
      end
    end
  end
end
