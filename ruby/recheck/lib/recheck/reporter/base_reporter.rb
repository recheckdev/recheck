module Recheck
  module Reporter
    class BaseReporter
      @subclasses = []

      # Register subclasses for `recheck reporters`.
      # Reporters don't need to inherit from BaseReporter, just meet its API
      class << self
        attr_reader :subclasses

        def inherited(subclass)
          super
          @subclasses << subclass
        end
      end

      def initialize(arg)
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

      # Optional: implement self.help to explain purpose or arg in 'recheck reporters'.
      def self.help
      end

      # A recheck run flows like this, with indicated calls to each reporter.
      #
      # -> before_run
      # for each Check class:
      #   -> before_check_class_run
      #   run query() to collect records
      #   for each 'check_' method on the class:
      #     for each record:
      #       check(record)
      #       -> check_result
      #   -> after_check_class_run
      # -> after_run

      def before_run
      end

      def before_check_class_run(check_class, check_methods)
      end

      def check_result(check_class, check_method, result)
      end

      def after_check_class_run(check_class, class_counts)
      end

      def after_run(total_counts)
      end
    end
  end
end
