# frozen_string_literal: true

module Philiprehberger
  module RuleEngine
    # Composite condition helpers for readable logic in condition blocks.
    module Helpers
      # Returns true if all conditions are truthy.
      #
      # @param conditions [Array<Boolean, Proc>] values or procs to evaluate
      # @return [Boolean]
      def all?(*conditions)
        conditions.all? { |c| c.is_a?(Proc) ? c.call : c }
      end

      # Returns true if any condition is truthy.
      #
      # @param conditions [Array<Boolean, Proc>] values or procs to evaluate
      # @return [Boolean]
      def any?(*conditions)
        conditions.any? { |c| c.is_a?(Proc) ? c.call : c }
      end

      # Returns true if no conditions are truthy.
      #
      # @param conditions [Array<Boolean, Proc>] values or procs to evaluate
      # @return [Boolean]
      def none?(*conditions)
        conditions.none? { |c| c.is_a?(Proc) ? c.call : c }
      end
    end
  end
end
