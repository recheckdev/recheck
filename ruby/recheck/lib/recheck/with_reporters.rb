# Decorates a Checker::V1 to call reporters.
module Recheck
  class WithReporters
    def initialize(checker_class:, reporters: [])
      @checker_class = checker_class
      @reporters = reporters
    end

    def run
      checker = @checker_class.new

      counts = CountStats.new

      @reporters.each do |reporter|
        reporter.around_checker(checker:, checks: @check_class.check_methods) do
          check.run do |check, result|
            @reporters.each do |r|
              r.around_check(checker:, check:) { result }
            end

            counts.increment(result.type)

            # if the first 20 error out, skip the check, it's probably buggy
            if counts.reached_blanket_failure?
              blanket = Error.new(checker_class: @checker_class, check:, record: nil, type: :blanket, exception: nil)
              @reporters.each do |r|
                r.around_check(check_class: @checker_class, check:) { blanket }
              end
              break
            end
          end

          counts
        end
      end

      counts
    end
  end
end
