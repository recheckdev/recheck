require "fileutils"
require "erb"

module Recheck
  module Command
    class Run
      def initialize(argv)
        @options = {
          reporters: []
        }
        @file_patterns = []

        @argv = argv
        @options = Optimist.options(@argv) do
          banner "recheck run: run the suite"
          opt :reporter, "<reporter>[:ARGS], can use multiple times", short: :r, multi: true, default: ["Recheck::Reporter::Default"]
        end
        @files_created = []

        @file_patterns = @options[:_leftovers]
      end

      def run
        run_checks
      end

      def run_checks
        checkers = load_checkers
        if checkers.empty?
          error = "No checks detected." +
            (@file_patterns.empty? ? " Did you run `bundle exec recheck setup`?" : "")
          warn error
          exit Cli::EXIT_CODE[:run_errors]
        end

        reporters = load_reporters(@options[:reporter])
        total_counts = CountStats.new
        begin
          reporters.each do |reporter|
            reporter.around_run(checkers: checkers) do
              checkers.each do |checker_class|
                checker_counts = WithReporters.new(checker_class:, reporters:).run
                total_counts << checker_counts
              end
              total_counts
            end
          end
        rescue Interrupt
          puts "\nOperation interrupted by user."
        rescue => e
          puts "\nAn unexpected error occurred:"
          puts e.full_message(highlight: false)
          exit Cli::EXIT_CODE[:run_error]
        ensure
          exit Cli::EXIT_CODE[total_counts.all_pass? ? :no_errors : :any_errors]
        end
      end

      def load_checkers
        files = if @file_patterns.empty?
          Dir.glob("recheck/**/*_checker.rb").sort
        else
          check_missing_files
          @file_patterns.flat_map do |pattern|
            if File.directory?(pattern)
              Dir.glob(File.join(pattern, "**/*.rb"))
            else
              Dir.glob(pattern)
            end
          end
        end
        # no .sort, respect user's given order
        files.each do |file|
          require File.expand_path(file)
        rescue => e
          puts "Loading #{file} threw an exception: #{e.class}: #{e.message}, #{e.backtrace.first}"
          unless file.start_with?("recheck/")
            puts "that filename doesn't start with \"recheck/\", did you give the name of a model instead of its checker?"
          end
          exit Cli::EXIT_CODE[:run_errors]
        end
        Recheck::Checker::Base.checker_classes
      end

      def check_missing_files
        missing_files = @file_patterns.reject { |pattern| Dir.glob(pattern).any? }
        unless missing_files.empty?
          puts "Error: The following files do not exist:"
          missing_files.each { |file| puts file }
          exit Cli::EXIT_CODE[:run_errors]
        end
      end

      def load_reporters(reporters)
        reporters.each { |option|
          class_name, arg = option.split(/(?<!:):(?!:)/, 2)
          resolve_reporter_class(class_name).new(arg:)
        }
      rescue ArgumentError => e
        puts "Bad argument to Reporter (#{e.backtrace.first}): #{e.message}"
        exit Cli::EXIT_CODE[:run_errors]
      end

      def resolve_reporter_class(reporter_name)
        [Object, Recheck::Reporter].each do |namespace|
          return namespace.const_get(reporter_name)
        rescue NameError
          next
        end
        puts "Error: Reporter class '#{reporter_name}' not found globally or in Recheck::Reporter."
        exit Cli::EXIT_CODE[:run_errors]
      end
    end
  end
end
