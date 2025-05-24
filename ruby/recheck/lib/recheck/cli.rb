require "optparse"

module Recheck
  class Cli
    EXIT_CODE = {
      no_errors: 0,  # all checks passed
      any_errors: 1, # any checks returns fail or threw exceptions
      run_errors: 2  # recheck itself encountered an error
    }

    def initialize(argv)
      @argv = argv
      @options = {
        reporters: []
      }
      @file_patterns = []
    end

    def run
      parse_options
      execute
    end

    private

    def parse_options
      OptionParser.new do |opts|
        opts.banner = "Usage: recheck [options] [file_patterns]"

        opts.on("--setup", "Generate basic checks based on existing models") do
          @options[:setup] = true
        end

        opts.on("--notify", "Use notify methods in checks") do
          @options[:notify] = true
        end

        opts.on("--reporter REPORTER[:ARGS]", "Reporter class name with optional arguments") do |reporter|
          class_name, arg = reporter.split(":", 2)
          @options[:reporters] << [class_name, arg]
        end

        opts.on("--list-reporters", "List available reporters") do
          list_reporters
          exit EXIT_CODE[:no_errors]
        end

        opts.on_tail("--version", "Show version") do
          puts "Recheck version #{Recheck::VERSION}"
          exit EXIT_CODE[:no_errors]
        end
      end.parse!(@argv)

      # fix `recheck setup` -> `recheck --setup`
      if @argv.first == "setup"
        @options[:setup] = true
        @argv.shift
      end

      if @options[:reporters].empty?
        @options[:reporters] = [["DefaultReporter", nil]]
      end

      @file_patterns = @argv
    end

    def execute
      if @options[:setup]
        puts "Running setup..."
        Setup.run
      else
        run_checks(notify: @options[:notify])
      end
    rescue Interrupt
      puts "\nOperation cancelled by user."
      exit EXIT_CODE[:run_errors]
    end

    def run_checks(notify: false)
      checks = load_checks
      if checks.empty?
        error = "No checks detected." +
          (@file_patterns.empty? ? " Did you run `bundle exec recheck --setup`?" : "")
        warn error
        exit EXIT_CODE[:run_errors]
      end

      reporters = load_reporters(@options[:reporters])
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
      reporters.map { |class_name, arg|
        resolve_reporter_class(class_name).new(arg)
      }
    rescue ArgumentError => e
      puts "Bad argument to Reporter (#{e.backtrace.first}): #{e.message}"
      exit EXIT_CODE[:run_errors]
    end

    def list_reporters
      puts "Available reporters (add yours to recheck/reporter/):"
      Recheck::Reporter::BaseReporter.subclasses.each do |reporter_class|
        name = reporter_class.name.sub(/^Recheck::Reporter::/, "")
        help = begin
          reporter_class.help
        rescue
          "No help available"
        end
        puts "  #{name}: #{help}"
      end
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
