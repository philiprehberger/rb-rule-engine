# frozen_string_literal: true

module Philiprehberger
  module RuleEngine
    # A lightweight rule engine with declarative conditions and actions.
    class Engine
      include Helpers

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
        @stats = {}
        instance_eval(&block) if block
      end

      # Define a rule using the DSL.
      #
      # @param name [String] the rule name
      # @yield [rule] block for configuring the rule
      # @return [Rule] the created rule
      def rule(name, tags: [], &block)
        r = Rule.new(name, tags: tags)
        r.instance_eval(&block) if block
        @rules << r
        @stats[name] = new_stat_entry
        r
      end

      # Add a rule after engine creation.
      #
      # @param name [String] the rule name
      # @param tags [Array<Symbol>] optional tags
      # @yield [rule] block for configuring the rule
      # @return [Rule] the created rule
      def add_rule(name, tags: [], &block)
        rule(name, tags: tags, &block)
      end

      # Remove a rule by name.
      #
      # @param name [String] the rule name to remove
      # @return [Rule, nil] the removed rule, or nil if not found
      def remove_rule(name)
        index = @rules.index { |r| r.name == name }
        return nil unless index

        removed = @rules.delete_at(index)
        @stats.delete(name)
        removed
      end

      # Disable a rule by name (skipped during evaluation).
      #
      # @param name [String] the rule name to disable
      # @return [void]
      def disable_rule(name)
        found = @rules.find { |r| r.name == name }
        raise Error, "rule not found: #{name}" unless found

        found.enabled = false
      end

      # Enable a rule by name.
      #
      # @param name [String] the rule name to enable
      # @return [void]
      def enable_rule(name)
        found = @rules.find { |r| r.name == name }
        raise Error, "rule not found: #{name}" unless found

        found.enabled = true
      end

      # Return rules matching a specific tag.
      #
      # @param tag [Symbol] the tag to filter by
      # @return [Array<Rule>]
      def rules_by_tag(tag)
        @rules.select { |r| r.tags.include?(tag.to_sym) }
      end

      # Evaluate all rules against the given facts.
      #
      # @param facts [Object] the facts to evaluate
      # @param tags [Array<Symbol>, nil] only evaluate rules with at least one matching tag
      # @return [Array<Hash>] results with :rule and :result for each matched rule
      def evaluate(facts, tags: nil)
        sorted = filter_by_tags(@rules.select(&:enabled), tags).sort_by(&:priority)
        results = []

        sorted.each do |r|
          stat = @stats[r.name] ||= new_stat_entry
          stat[:evaluations] += 1

          next unless r.matches?(facts)

          stat[:matches] += 1
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = r.execute(facts)
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

          stat[:executions] += 1
          stat[:total_time] += elapsed
          stat[:avg_time] = stat[:total_time] / stat[:executions]
          stat[:last_triggered] = Time.now

          results << { rule: r.name, result: result }
          break if @mode == :first
        end

        results
      end

      # Return per-rule execution statistics.
      #
      # @return [Hash] stats keyed by rule name
      def stats
        @stats.transform_values do |s|
          {
            evaluations: s[:evaluations],
            matches: s[:matches],
            executions: s[:executions],
            avg_time: s[:avg_time],
            last_triggered: s[:last_triggered]
          }
        end
      end

      # Reset all execution statistics.
      #
      # @return [void]
      def reset_stats!
        @stats.each_key { |k| @stats[k] = new_stat_entry }
      end

      # Evaluate rules without executing actions, return matched rule info
      #
      # @param facts [Hash] the facts to evaluate
      # @return [Array<Hash>] matched rules with name and priority
      def dry_run(facts, tags: nil)
        matched = filter_by_tags(enabled_rules_sorted, tags).select { |rule| rule.matches?(facts) }
        matched = [matched.first].compact if @mode == :first
        matched.map { |rule| { name: rule.name, priority: rule.priority } }
      end

      # Find rules with potentially overlapping conditions
      #
      # @return [Array<Hash>] pairs of rule names that could both match
      def detect_conflicts
        pairs = []
        sorted = enabled_rules_sorted
        sorted.combination(2) do |a, b|
          pairs << { rules: [a.name, b.name], priorities: [a.priority, b.priority] }
        end
        pairs
      end

      # Validate all rules have conditions and actions defined
      #
      # @return [Hash] { valid: Boolean, issues: Array<String> }
      def validate_rules
        issues = []
        @rules.each do |rule|
          issues << "Rule '#{rule.name}' has no condition" unless rule.instance_variable_get(:@condition)
          issues << "Rule '#{rule.name}' has no action" unless rule.instance_variable_get(:@action)
        end
        { valid: issues.empty?, issues: issues }
      end

      # Serialize the engine configuration to a hash.
      #
      # @return [Hash] engine metadata including mode and rules
      def to_h
        {
          mode: @mode,
          rules: @rules.map(&:to_h)
        }
      end

      # Execute rules sequentially as a pipeline.
      # Each rule's action result is passed as input: to the next rule.
      #
      # @param rule_names [Array<String>] ordered rule names to chain
      # @return [Object] the final action's result
      def chain(*rule_names)
        chain_rules = rule_names.map do |name|
          found = @rules.find { |r| r.name == name }
          raise Error, "rule not found: #{name}" unless found

          found
        end

        input = nil
        chain_rules.each do |r|
          facts = { input: input }
          input = r.execute(facts)
        end

        input
      end

      private

      def filter_by_tags(rules, tags)
        return rules unless tags

        tag_syms = tags.map(&:to_sym)
        rules.select { |r| r.tags.intersect?(tag_syms) }
      end

      def enabled_rules_sorted
        @rules.select(&:enabled).sort_by(&:priority)
      end

      def new_stat_entry
        {
          evaluations: 0,
          matches: 0,
          executions: 0,
          total_time: 0.0,
          avg_time: 0.0,
          last_triggered: nil
        }
      end
    end
  end
end
