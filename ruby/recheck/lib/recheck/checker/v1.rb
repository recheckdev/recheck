module Recheck
  module Checker
    class V1
      PASSTHROUGH_EXCEPTIONS = [NoMemoryError, SignalException, SystemExit]

      class << self
        def checker_classes
          @@checker_classes ||= Set.new
          @@checker_classes
        end

        def inherited(klass)
          register klass
        end

        # Call if you don't want to inherit from Recheck::Checker
        def register klass
          checker_classes << klass
        end
      end

      # Reflect for a list of queries to run. Override this if you don't want to start all your
      # query methods with `query` or you are metaprogramming query methods at runtime.
      def self.query_methods
        public_instance_methods(false).select { |m| m.to_s.start_with?("query") }
      end

      # Reflect for a list of checks to run. Override this if you don't want to start all your
      # check methods with `check` or you are metaprogramming check methods at runtime.
      def self.check_methods
        public_instance_methods(false).select { |m| m.to_s.start_with?("check") }
      end

      def initialize
        setup
      end

      def setup
      end

      def run
        success = Success.new

        # for each query_...
        self.class.query_methods.each do |query_method|
          # run the query for the records...
          public_send(query_method).each do |record|
            # and then run each check:
            self.class.check_methods.each do |check_method|
              result = public_send(check_method, record)
              if result
                yield check_method, success
              else
                error = Error.new(checker_class: self.class, check: check, record: record, type: :fail, exception: nil)
                yield check_method, error
              end
            rescue *PASSTHROUGH_EXCEPTIONS
              raise
            rescue => e
              error = Error.new(checker_class: self.class, check: check, record: record, type: :exception, exception: e)
              yield check_method, error
            end
          end
        rescue *PASSTHROUGH_EXCEPTIONS
          raise
        rescue => e
          yield "query", Error.new(checker_class: self.class, check: query_method, record: nil, type: :exception, exception: e)
          next
        end
      end
    end
  end
end
