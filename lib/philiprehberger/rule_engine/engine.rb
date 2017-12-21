# frozen_string_literal: true

module Philiprehberger
  module RuleEngine
    # A lightweight rule engine with declarative conditions and actions.
    class Engine
      # @return [Array<Rule>] the registered rules
      attr_reader :rules

      # @return [Symbol] the evaluation mode (:all or :first)
      attr_reader :mode

      # Create a new rule engine.
      #
      # @param mode [Symbol] :all to run all matching rules, :first to stop after first match
      # @yield [engine] block for defining rules using the DSL
      def initialize(mode: :all, &block)
        raise Error, 'mode must be :all or :first' unless %i[all first].include?(mode)

        @rules = []
        @mode = mode
        instance_eval(&block) if block
      end

      # Define a rule using the DSL.
      #
      # @param name [String] the rule name
      # @yield [rule] block for configuring the rule
      # @return [Rule] the created rule
      def rule(name, &block)
        r = Rule.new(name)
        r.instance_eval(&block) if block
        @rules << r
        r
      end

      # Evaluate all rules against the given facts.
      #
      # @param facts [Object] the facts to evaluate
      # @return [Array<Hash>] results with :rule and :result for each matched rule
      def evaluate(facts)
        sorted = @rules.sort_by(&:priority)
        results = []

        sorted.each do |r|
          next unless r.matches?(facts)

          result = r.execute(facts)
          results << { rule: r.name, result: result }
          break if @mode == :first
        end

        results
      end
    end
  end
end
