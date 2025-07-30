# frozen_string_literal: true

# Reporters are how you turn failing checks into emails, bug tracker tickets,
# or any other useful notification or report. You can notify different teams
# however they most "enjoy" hearing about bad data.

class SampleReporter < Recheck::Reporter::Base
  # Optional but strongly recommended: Provide help text that appears when running `recheck
  # reporters`. This should briefly explain what your reporter does and any argument it takes.
  def self.help
    "A template reporter showing how to implement your own custom reporter. Takes an optional argument."
  end

  # Optional: Initialize with the argument string from the command line.
  # The arg is passed as a single string, or nil if no arg is provided
  # Arguments:
  # * arg: The string argument passed after the colon in the reporter specification
  #   For example: `--reporter SampleReporter:api_key_123` -> `api_key_123`
  def initialize(arg:)
    # Process your argument here if needed
    @config = arg || "default_config"
  end

  # Important: If you define an around_ hook, it must 'yield' to run the next step.
  # A hook method's return value is not used.

  # around_run: Fires around the entire run.
  # This is a good place to set up resources, send summary emails, etc.
  # Arguments:
  # * checkers: Array of checker instances that will be run
  def around_run(checkers: [])
    # Setup before the run
    start_time = Time.now

    # yield returns: a CountStats about the entire run
    # CountStats tracks counts of passes, failures, and other result types
    # It provides methods like #all_pass?, #any_errors?, #summary, etc.
    total_counts = yield

    # Teardown/reporting after the run
    duration = Time.now - start_time

    # Example of how you might report results
    if total_counts.any_errors?
      puts "SampleReporter: Found errors in #{duration.round(2)}s: #{total_counts.summary}"
      # In a real reporter, you might:
      # - Send an email
      # - Post to Slack
      # - Create a ticket in your issue tracker
      # - Log to a monitoring service
    end

    # Return the counts (optional)
    total_counts
  end

  # around_checker: Fires around each checker.
  # Arguments:
  # * checker: The checker instance being run
  # * queries: Array of query method names defined on the checker
  # * checks: Array of check method names defined on the checker
  def around_checker(checker:, queries: [], checks: [])
    # Before running this checker
    checker_name = checker.class.name

    # yields returns a CountStats for the checker
    counts = yield

    # After running this checker
    if counts.any_errors?
      puts "SampleReporter: Checker #{checker_name} had issues: #{counts.summary}"
      # In a real reporter, you might group errors by checker
    end
  end

  # around_query: Fires around each query
  # This is useful for tracking which queries are slow or problematic
  # Arguments:
  # * checker: The checker instance being run
  # * query: The name of the query method being executed
  # * checks: Array of check method names that will be run against query results
  def around_query(checker:, query:, checks: [])
    # Before running this query
    query_start = Time.now

    # yield does not return anything for this hook
    yield

    # After running this query
    query_duration = Time.now - query_start
    if query_duration > 5 # seconds
      puts "SampleReporter: Slow query #{checker.class.name}##{query} took #{query_duration.round(2)}s"
    end
  end

  # The around_check and halt hooks both receive one of two result objects.
  #
  # Recheck::Pass: A successful check.
  # Attributes:
  #   #type: always :pass
  #
  # Recheck::Error: A failed check.
  # Attributes:
  #   #type: One of the following symbols
  #     fail: The check returned a falsey value
  #     exception: The check raised an exception
  #     blanket: The first 20 checks all failed or raised; the runner skips
  #     no_query_methods: The checker does not define a query_methods
  #     no_queries: The checker defines query_methods, but did not return any
  #     no_check_methods: The checker does not define a check_methods
  #     no_checks: The checker defines check_methods, but did not return any
  #   #checker: Checker instance
  #   #query: Query method name
  #   #check: Check method name
  #   #record: The record being checked
  #   #exception: rescued Exception
  #

  # around_check: Fires for each call to a check_ method on each record
  # This is where you can collect detailed information about failures.
  # Arguments:
  # * checker: The checker instance being run
  # * query: The name of the query method that produced this record
  # * check: The name of the check method being executed
  # * record: The individual record being checked
  def around_check(checker:, query:, check:, record:)
    # Returns a result object, see comment above
    result = yield

    # Process the result
    if result.is_a?(Recheck::Error)
      case result.type
      when :fail
        record_id = fetch_record_id(result.record)
        puts "SampleReporter: #{checker.class.name}##{check} failed for record: #{record_id}"
      when :exception
        puts "SampleReporter: #{checker.class.name}##{check} raised exception: #{result.exception.message}"
      end

      # In a real reporter, you might:
      # - Collect failures to report in a batch
      # - Send immediate alerts for critical failures
      # - Log to a monitoring system
    end
  end

  # halt: Called when a checker is halted due to an error.
  # This is useful for reporting fatal errors that prevent checks from running
  # Arguments:
  # * checker: The checker instance that was halted
  # * query: The name of the query method that was running (if any)
  # * check: The name of the check method that was running (if any)
  # * error: The error result, see comment above around_check
  def halt(checker:, query:, error:, check: nil)
    puts "SampleReporter: Halted #{checker.class.name}##{query} due to #{error.type}"

    # In a real reporter, you might:
    # - Send an urgent alert
    # - Create a high-priority ticket
    # - Log a critical error
  end

  # You can add any helper methods, include modules, etc.

  # Example of a helper method to format data for reporting
  def format_error_message(error)
    case error.type
    when :fail
      "Record is invalid"
    when :exception
      "Exception occurred: #{error.exception.message}"
    when :blanket
      "Blanket failure - first 20 checks all failed"
    else
      "Other error: #{error.type}"
    end
  end
end
