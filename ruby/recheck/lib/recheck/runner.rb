# frozen_string_literal: true

module Recheck
  class Runner
    PASSTHROUGH_EXCEPTIONS = [NoMemoryError, SignalException, SystemExit]

    def initialize(checkers: [], reporters: [])
      # ruby sets maintain order and we want to check/report in user-provided order
      @checkers = checkers.to_set
      @reporters = reporters.to_set
    end

    # compose reporter hooks so they each see the block fire once at 'yield'
    def reduce(hook:, kwargs: {}, reporters: [], &blk)
      reporters.reverse.reduce(blk) do |proc, reporter|
        -> {
          result = nil
          reporter.public_send(hook, kwargs) {
            result = proc.call.freeze
          }
          result
        }
      end.call
    end

    # n queries * n check methods * n records = O(1) right?
    def run
      total_counts = CountStats.new
      # All happy families are alike; each unhappy family is unhappy in its own way.
      success = Success.new

      # for want of a monad...
      reduce(reporters: @reporters, hook: :around_run, kwargs: {checkers:}) do
        # for each checker...
        checkers.each do |checker|
          checker_counts = CountStats.new
          queries = checker.query_methods
          checks = checker.check_methods

          reduce(reporters: @reporters, hook: :around_checker, kwargs: {checker:, queries:, checks:}) do
            # for each query_...
            queries.each do |query|
              # for each record...
              checker.public_send(query).each do |record|
                # for each check_method...
                checks.each do |check|
                  check_counts = CountStats.new

                  # ...run check(record)
                  result = checker.public_send(check, record)

                  begin
                    check_counts.increment(result.type)
                  rescue *PASSTHROUGH_EXCEPTIONS
                    raise
                  rescue => e
                    result = Error.new(checker:, check:, record: record, type: :exception, exception: e)
                  end

                  # if the first 20 error out, skip the check method, it's probably buggy
                  if check_counts.reached_blanket_failure?
                    blanket = Error.new(checker:, check:, record: nil, type: :blanket, exception: nil)
                    @reporters.each do |r|
                      r.around_check(check_class: @checker_class, check:) { blanket }
                    end
                    break
                  end

                  @reporters.each do |check_reporter|
                    check_reporter.around_check(checker:, check:, record:) { result }
                  end
                  checker_counts << check_counts
                end
              end
            rescue *PASSTHROUGH_EXCEPTIONS
              raise
            rescue => e
              @reporters.each do |check_reporter|
                result = Error.new(checker:, check: query, record: nil, type: :exception, exception: e)
                check_reporter.around_check(checker:, check: query, record: nil) { result }
              end
            end
            checker_counts
          end
          total_counts << checker_counts
        end
      end
      total_counts
    end
  end
end
