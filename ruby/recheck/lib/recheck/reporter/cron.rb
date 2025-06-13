module Recheck
  module Reporter
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

        if counts.fail > 0 or counts.exception > 0
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
    end
  end
end
