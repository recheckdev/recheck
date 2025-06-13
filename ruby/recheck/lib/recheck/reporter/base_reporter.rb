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
      # -> around_run yields to run all checks, returning the totals:
      # for each Check class:
      #   -> around_check_class_run yields to run each check class:
      #   run query() to collect records
      #   for each 'check_' method on the class:
      #     for each record:
      #       -> around_check yields to run check(record), returning the result

      def around_run(check_classes: [])
        total_count = yield
      end

      def around_check_class_run(check_class:, check_methods: [])
        class_counts = yield
      end

      def around_check(check_class:, check_method:)
        result = yield
      end
    end
  end
end
