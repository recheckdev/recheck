# frozen_string_literal: true

module Recheck
  class Runner
    def initialize(checkers: [], reporters: [])
      # ruby sets maintain order and we want to check/report in user-provided order
      @checkers = checkers.to_set
      @reporters = reporters.to_set
      @total_counts = CountStats.new
    end

    def run
      reporters.each do |reporter|
        reporter.around_run(checkers: checkers) do
          checkers.each do |checker_class|
            checker_counts = WithReporters.new(checker_class:, reporters:).run
            @total_counts << checker_counts
          end
        end
      end

      @total_counts
    end
  end
end
