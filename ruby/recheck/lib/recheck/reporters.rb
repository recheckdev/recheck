module Recheck
  module Reporter
    class Base
      @subclasses = []

      # Register subclasses for `recheck reporters`.
      class << self
        attr_reader :subclasses

        def inherited(subclass)
          super
          @subclasses << subclass
        end
      end

      def self.help
      end

      def initialize(arg:)
      end

      def fetch_record_id(record)
        if Recheck.unloaded_is_a? record, "ActiveRecord::Base"
          record.id.to_s
          # or: record.to_global_id, if you want to override in
          # your_app/recheck/reporter/base_reporter.rb
        elsif Recheck.unloaded_is_a? record, "Sequel::Model"
          record.pk.to_s # may be an array
        else
          record.to_s
        end
      end

      # A recheck run flows like this, with indicated calls to each reporter.
      #
      # around_run -> for each Checker class:
      #   around_checker ->
      #     run each query() method
      #     for each 'check_' method on the checker:
      #       for each record queried:
      #         around_check -> check(record)

      def around_run(checkers: [])
        total_count = yield
      end

      def around_checker(checker:, queries: [], checks: [])
        counts = yield
      end

      def around_check(checker:, check:, record:)
        result = yield
      end

      def halt(checker:, error:, check:)
        # running the checker was halted, so there's no result available for yield
      end
    end # Base

    class Cron < Base
      def self.help
        "Prints failures/exceptions but nothing on success. For use in cron jobs, which use silence to incidate success."
      end

      def initialize(arg:)
        raise ArgumentError, "does not take options" unless arg.nil?
        @errors = []
      end

      def around_run(checkers: [])
        total_counts = yield

        if total_counts.any_errors?
          puts "Total: #{total_counts.summary}"
        end
      end

      def around_checker(checker:, queries:, checks:)
        @errors = []

        counts = yield

        if counts.any_errors?
          puts "#{checker.class}: #{counts.summary}"
          print_errors
        end
      end

      def around_check(checker:, check:)
        result = yield
        @errors << result if result.is_a? Error
      end

      def halt(checker:, error:, check: nil)
        @errors << error
      end

      def print_errors
        failure_details = []
        grouped_errors = @errors.group_by { |e| [e.checker_class, e.check, e.type] }

        grouped_errors.each do |(checker_class, check), group_errors|
          case group_errors.first.type
          when :fail
            ids = group_errors.map { |e| fetch_record_id(e.record) }.join(", ")
            failure_details << "  #{checker_class}##{check} failed for records: #{ids}"
          when :exception
            error = group_errors.first
            error_message = "  #{checker_class}##{check} exception #{error.exception.message} for #{group_errors.size} records"
            failure_details << error_message
            failure_details << error.record.full_message(highlight: false, order: :top) if error.record.respond_to?(:full_message)
          when :blanket
            failure_details << "  #{checker_class}: Skipping because the first 20 checks all failed. Either there's a lot of bad data or there's something wrong with the checks."
          end
        end
        puts failure_details
      end
    end # Cron

    class Default < Base
      def self.help
        "Used when no --reporter is named. Prints incremental progress to stdout. No options."
      end

      def initialize(arg:)
        raise ArgumentError, "does not take options" unless arg.nil?
        @current_counts = CountStats.new
        @errors = []
      end

      def around_run(checkers: [])
        total_counts = yield

        puts "Total: #{total_counts.summary}"
        puts "Queries found no records to check (this is OK when queries can select only invalid data)" if total_counts.all_zero?

        total_counts
      end

      def around_checker(checker:, queries:, checks:, check: [])
        @errors = []

        print "#{checker.class}: "
        counts = yield

        # don't double-print last progress indicator
        print_progress unless @current_counts.total % 1000 == 0
        print_check_summary(counts)
        print_errors

        counts
      end

      def around_check(checker:, check:)
        result = yield

        @current_counts.increment(result.type)
        print_progress if @current_counts.total % 1000 == 0

        @errors << result if result.is_a? Error
      end

      def halt(checker:, error:, check: nil)
        @errors << error
      end

      def print_check_summary(counts)
        puts "  #{counts.summary}"
      end

      def print_errors
        failure_details = []
        grouped_errors = @errors.group_by { |e| [e.checker, e.check, e.type] }

        grouped_errors.each do |(checker_class, check), group_errors|
          case group_errors.first.type
          when :fail
            ids = group_errors.map { |e| fetch_record_id(e.record) }.join(", ")
            failure_details << "  #{checker_class}##{check} failed for records: #{ids}"
          when :exception
            error = group_errors.first
            error_message = "  #{checker_class}##{check} exception #{error.exception.message} for #{group_errors.size} records"
            failure_details << error_message
            failure_details << error.record.full_message(highlight: false, order: :top) if error.record.respond_to?(:full_message)
          when :no_query_methods
            failure_details << "  #{checker_class}: Did not define .query_methods"
          when :no_queries
            failure_details << "  #{checker_class} does not report any query methods (via .query_methods)"
          when :no_check_methods
            failure_details << "  #{checker_class}: Did not define .check_methods"
          when :no_checks
            failure_details << "  #{checker_class} does not report any check methods (via .check_methods)"
          when :blanket
            failure_details << "  #{checker_class}: Skipping because the first 20 checks all failed. Either there's a lot of bad data or there's something wrong with the checks."
          else
            failure_details << "  #{checker_class} unknown error"
          end
        end
        puts failure_details
      end

      def print_progress
        print @current_counts.all_pass? ? "." : "x"
        @current_counts = CountStats.new
      end
    end # Default

    class Json < Base
      def self.help
        "Outputs JSON-formatted results to a file or stdout. Arg is filename or blank for stdout."
      end

      def initialize(arg:)
        @filename = arg
        @results = {}
      end

      def around_checker(checker:, queries:, checks:, check: [])
        @results[checker.to_s] = checks.to_h { |method|
          [method, {
            counts: CountStats.new,
            fail: [],
            exception: []
          }]
        }
        yield
      end

      def around_check(checker:, checks:)
        result = yield

        @results[checker.class.to_s][check][:counts].increment(result.type)
        case result.type
        when :fail
          @results[checker.class.to_s][check][:fail] << fetch_record_id(result.record)
        when :exception
          @results[checker.class.to_s][check][:exception] << {
            id: fetch_record_id(result.record),
            message: result.exception.message,
            backtrace: result.exception.backtrace
          }
        end

        if @filename
          File.write(@filename, @results.to_json)
        else
          puts @results.to_json
        end
      end

      def halt(checker:, error:, check: "meta")
        @results[checker.class.to_s][check][:halt] = error.type
      end
    end # Json

    class Silent < Base
      def self.help
        "Prints nothing. Useful for checks that can automatically fix issues."
      end

      def initialize(arg:)
        raise ArgumentError, "does not take options" unless arg.nil?
      end
    end # Silent
  end
end
