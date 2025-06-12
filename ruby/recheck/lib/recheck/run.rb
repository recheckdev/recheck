require "fileutils"
require "erb"

require_relative "../../vendor/optimist"

module Recheck
  class Run
    def initialize(argv)
      @options = {
        reporters: []
      }
      @file_patterns = []

      @argv = argv
      @options = Optimist.options(@argv) do
        banner "recheck run: run the suite"
        opt :reporter, "<reporter>[:ARGS], can use multiple times", short: :r, multi: true, default: ["DefaultReporter"]
        opt :notify, "Call .notify methods in checks", short: :n, type: :boolean
      end
      @files_created = []

      @file_patterns = @argv
    end

    def run
      run_checks
    end

    def run_checks(notify: false)
      checks = load_checks
      if checks.empty?
        error = "No checks detected." +
          (@file_patterns.empty? ? " Did you run `bundle exec recheck --setup`?" : "")
        warn error
        exit EXIT_CODE[:run_errors]
      end

      reporters = load_reporters(@options[:reporter])
      total_counts = CountStats.new
      reporters.each(&:before_run)
      begin
        checks.each do |check_class|
          check_counts = WithReporters.new(check_class, reporters: reporters).run(notify)
          total_counts << check_counts
        end
      rescue Interrupt
        puts "\nOperation interrupted by user."
      rescue => e
        puts "\nAn unexpected error occurred:"
        puts e.full_message(highlight: false)
        exit EXIT_CODE[:run_error]
      ensure
        reporters.each { |r| r.after_run(total_counts) }
        exit EXIT_CODE[total_counts.all_pass? ? :no_errors : :any_errors]
      end
    end

    def load_checks
      files = if @file_patterns.empty?
        Dir.glob("recheck/**/*_check.rb").sort
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
        unless file.start_with?("recheck")
          puts "path doesn't start with \"recheck\", did you give the name of a model instead of its check?"
        end
        exit EXIT_CODE[:run_errors]
      end
      Recheck::Check::V1.check_classes
    end

    def check_missing_files
      missing_files = @file_patterns.reject { |pattern| Dir.glob(pattern).any? }
      unless missing_files.empty?
        puts "Error: The following files do not exist:"
        missing_files.each { |file| puts file }
        exit EXIT_CODE[:run_errors]
      end
    end

    def load_reporters(reporters)
      reporters.each { |option|
        class_name, arg = option.split(":", 2)
        resolve_reporter_class(class_name).new(arg)
      }
    rescue ArgumentError => e
      puts "Bad argument to Reporter (#{e.backtrace.first}): #{e.message}"
      exit EXIT_CODE[:run_errors]
    end

    def resolve_reporter_class(reporter_name)
      [Object, Recheck::Reporter].each do |namespace|
        return namespace.const_get(reporter_name)
      rescue NameError
        next
      end
      puts "Error: Reporter class '#{reporter_name}' not found globally or in Recheck::Reporter."
      exit EXIT_CODE[:run_errors]
    end
  end
end
