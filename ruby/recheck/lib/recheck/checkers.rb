module Recheck
  module Checker
    class Base
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
    end
  end
end
