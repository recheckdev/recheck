module Recheck
  module Check
    class V1
      PASSTHROUGH_EXCEPTIONS = [NoMemoryError, SignalException, SystemExit]

      class << self
        def check_classes
          @@check_classes
        end

        def inherited(klass)
          register klass
        end

        # Hook if you don't want to inherit from Recheck::Check
        def register klass
          @@check_classes ||= Set.new
          @@check_classes << klass
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

      def run(notify)
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
                error = Error.new(check_class: self.class, check_method: check_method, record: record, type: :fail, exception: nil)
                self.notify(error) if notify
                yield check_method, error
              end
            rescue *PASSTHROUGH_EXCEPTIONS
              raise
            rescue => e
              error = Error.new(check_class: self.class, check_method: check_method, record: record, type: :exception, exception: e)
              self.notify(error) if notify
              yield check_method, error
            end
          end
        rescue *PASSTHROUGH_EXCEPTIONS
          raise
        rescue => e
          yield "query", Error.new(check_class: self.class, check_method: query_method, record: nil, type: :exception, exception: e)
          return
        end
      end

      def notify(error)
      end
    end
  end
end
