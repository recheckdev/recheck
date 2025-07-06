# frozen_string_literal: true

module Recheck
  class HookDidNotYield < RuntimeError; end

  class HookYieldedTwice < RuntimeError; end

  class UnexpectedHookYield < RuntimeError; end

  class UnexpectedReporterYield < RuntimeError; end

  class Yields
    def initialize
      @executions = {}
    end

    def expect(hook:, reporter:)
      @executions[hook] ||= {}
      @executions[hook][reporter] = false
      # puts "expect #{hook}, #{reporter.class.name}, id #{reporter.id}"
    end

    def ran(hook:, reporter:)
      raise UnexpectedHookYield, "Ran an unexpected hook #{hook} (for reporter #{reporter})" unless @executions.include? hook
      raise UnexpectedReporterYield, "Ran an expected hook #{hook} for an unexpected reporter #{reporter}" unless @executions[hook].include? reporter
      raise HookYieldedTwice, "Ran a hook #{hook} twice for reporter #{reporter}" unless @executions[hook][reporter] == false

      # puts "ran #{hook}, #{reporter}, #{reporter.id}"
      @executions[hook][reporter] = true
    end

    def raise_unless_all_reporters_yielded(hook:)
      didnt_yield = @executions[hook].filter { |reporter, ran| ran == false }
      raise HookDidNotYield, "Reporter(s) [#{didnt_yield.keys.join(", ")}] did not yield in their #{hook} hook" if didnt_yield.any?
    end
  end

  class Runner
    PASSTHROUGH_EXCEPTIONS = [
      # ours
      HookDidNotYield, HookYieldedTwice, UnexpectedHookYield,
      # Ruby's
      NoMemoryError, SignalException, SystemExit
    ]

    def initialize(checkers: [], reporters: [])
      # maintain order and we want to check/report in user-provided order; Set lacks .reverse
      @checkers = checkers.uniq
      @reporters = reporters.uniq
      @yields = Yields.new
    end

    # compose reporter hooks so they each see the block fire once at 'yield'
    def reduce(hook:, kwargs: {}, reporters: [], &blk)
      reporters.reverse.reduce(blk) do |proc, reporter|
        @yields.expect(hook:, reporter:)
        -> {
          result = nil
          reporter.public_send(hook, **kwargs) {
            @yields.ran(hook:, reporter:)
            result = proc.call.freeze
          }
          result
        }
      end.call
    end

    # only for calling from inside run()
    def cant_run reporters:, checker:, queries:, checks:, type:
      checker_counts = CountStats.new
      checker_counts.increment type
      @total_counts << checker_counts

      error = Error.new(checker:, check: nil, record: nil, type:, exception: nil)
      reduce(reporters:, hook: :around_checker, kwargs: {checker:, queries:, checks:}) do
        reporters.each { it.halt(checker:, error:, check: nil) }
        checker_counts
      end
    end

    # n queries * n check methods * n records = O(1) right?
    def run
      @total_counts = CountStats.new
      # All happy families are alike; each unhappy family is unhappy in its own way.
      success = Success.new

      # for want of a monad...
      reduce(reporters: @reporters, hook: :around_run, kwargs: {checkers: @checkers}) do
        # for each checker...
        @checkers.each do |checker|
          checker_counts = CountStats.new
          puts "checker is #{checker} with class #{checker.class}"
          if !checker.class.respond_to?(:query_methods)
            cant_run(reporters: @reporters, checker:, type: :no_query_methods, queries: nil, checks: nil)
            break
          end
          if (queries = checker.class.query_methods).empty?
            cant_run(reporters: @reporters, checker:, type: :no_queries, queries:, checks: nil)
            break
          end

          if !checker.class.respond_to?(:check_methods)
            cant_run(reporters: @reporters, checker:, type: :no_check_methods, queries:, checks: nil)
            break
          end
          if (checks = checker.class.check_methods).empty?
            cant_run(reporters: @reporters, checker:, type: :no_checks, queries:, checks:)
            break
          end

          reduce(reporters: @reporters, hook: :around_checker, kwargs: {checker:, queries:, checks:}) do
            # for each query_...
            queries.each do |query|
              checker_counts.increment :queries
              # for each record...
              # TODO: must handle if the query method yields (find_each) OR returns (current)
              checker.public_send(query).each do |record|
                # for each check_method...
                checks.each do |check|
                  check_counts = CountStats.new

                  begin
                    raw_result = nil
                    reduce(reporters: @reporters, hook: :around_check, kwargs: {checker:, check:, record:}) do
                      raw_result = checker.public_send(check, record)
                    end
                    @yields.raise_unless_all_reporters_yielded(hook: :around_check)
                  rescue *PASSTHROUGH_EXCEPTIONS
                    raise
                  rescue => e
                    result = Error.new(checker:, check:, record:, type: :exception, exception: e)
                  end

                  result = raw_result ? success : Error.new(checker:, check:, record:, type: :fail)
                  check_counts.increment(result.type)

                  # if the first 20 error out, halt the check method, it's probably buggy
                  if check_counts.reached_blanket_failure?
                    checker_counts.increment :blanket

                    error = Error.new(checker:, check: nil, record: nil, type: :blanket, exception: nil)
                    reporters.each { it.halt(checker:, error:, check:) }

                    break
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
          @yields.raise_unless_all_reporters_yielded(hook: :around_checker)
          @total_counts << checker_counts
        end
        @total_counts
      end
      @yields.raise_unless_all_reporters_yielded(hook: :around_run)
    end
  end
end
