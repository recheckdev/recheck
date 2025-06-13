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

        if total_counts.all_zero?
          puts "No records returned by query methods"
        elsif total_counts.fail > 0 || total_counts.exception > 0
          puts "Total: #{total_counts.pass} pass, #{total_counts.fail} fail, #{total_counts.exception} exception"
        end
      end

      def around_checker(checker:, check: [])
        @errors = []

        counts = yield

        if counts.fail > 0 || counts.exception > 0
          puts "#{checker.class}: #{counts.pass} pass, #{counts.fail} fail, #{counts.exception} exception"
          print_errors
        end
      end

      def around_check(checker:, check:)
        result = yield
        @errors << result if result.is_a? Error
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

        if total_counts.all_zero?
          puts "No records returned by query methods"
        else
          puts "Total: #{total_counts.pass} pass, #{total_counts.fail} fail, #{total_counts.exception} exception"
        end

        total_counts
      end

      def around_checker(checker:, check: [])
        @errors = []
        print "#{checker.class} "

        counts = yield

        # don't double-print last progress indicator
        print_progress unless @current_counts.total % 1000 == 0
        print_check_summary(counts)
        print_errors

        counts
      end

      def around_check(checker:, check:)
        result = yield

        @current_counts.increment(result.type) unless result.type == :blanket
        print_progress if @current_counts.total % 1000 == 0

        @errors << result if result.is_a? Error
      end

      def print_check_summary(counts)
        puts " #{counts.pass} pass, #{counts.fail} fail, #{counts.exception} exception"
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

      def print_progress
        print (@current_counts.fail + @current_counts.exception == 0) ? "." : "x"
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

      def around_checker(checker:, checks: [])
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
        when :blanket
          @results[checker.class.to_s][check][:blanket] = true
        end

        if @filename
          File.write(@filename, @results.to_json)
        else
          puts @results.to_json
        end
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
