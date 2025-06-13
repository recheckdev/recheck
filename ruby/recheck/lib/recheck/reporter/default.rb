module Recheck
  module Reporter
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
    end
  end
end
