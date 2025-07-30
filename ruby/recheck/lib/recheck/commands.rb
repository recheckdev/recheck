# frozen_string_literal: true

require "fileutils"
require "erb"

module Recheck
  module Command
    class Reporters
      def initialize(argv: [])
        @options = Optimist.options(argv) do
          banner "recheck list_reporters: load and list reporters"
          opt :location, "Show source location", short: :l, type: :boolean, default: false
        end
      end

      def run
        puts "Available reporters (add yours to recheck/reporter/):\n"
        Recheck::Reporter::Base.subclasses.each do |reporter_class|
          help = reporter_class.respond_to?(:help) ? reporter_class.help : nil
          help ||= "No help avalable"
          puts "#{reporter_class.name}   #{help}"
          puts %(  #{Object.const_source_location(reporter_class.to_s).join(":")}) if @options[:location]
        end
      end
    end # Reporters

    class Run
      def initialize(argv: [])
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
        checkers = load_checkers
        reporters = load_reporters(@options[:reporter])

        total_counts = Runner.new(checkers:, reporters:).run
      rescue Interrupt
        puts "\nOperation interrupted by user."
      rescue => e
        puts "\nAn error occurred in Recheck:"
        puts e.full_message(highlight: false)
        exit Cli::EXIT_CODE[:recheck_error]
        # ensure
        #  puts "ensure"
        #  exit Cli::EXIT_CODE[total_counts&.all_pass? ? :no_errors : :any_errors]
      end

      def load_checkers
        files = if @file_patterns.empty?
          Dir.glob("recheck/**/*.rb").sort
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

        files.each do |file|
          # bug: if the file has a syntax error, Ruby silently exits instead of raising SyntaxError
          require File.expand_path(file)
        rescue LoadError => e
          puts "Loading #{file} threw an exception: #{e.class}: #{e.message}, #{e.backtrace.first}"
          unless file.start_with?("recheck/")
            puts "that filename doesn't start with \"recheck/\", did you give the name of a model instead of its checker?"
          end
          exit Cli::EXIT_CODE[:load_error]
        end

        if Recheck::Checker::Base.checker_classes.empty?
          error = "No checks detected." +
            (@file_patterns.empty? ? " Did you run `bundle exec recheck setup`?" : "")
          warn error
          exit Cli::EXIT_CODE[:load_error]
        end

        Recheck::Checker::Base.checker_classes.map(&:new)
      end

      def check_missing_files
        missing_files = @file_patterns.reject { |pattern| Dir.glob(pattern).any? }
        unless missing_files.empty?
          puts "Error: The following files do not exist:"
          missing_files.each { |file| puts file }
          exit Cli::EXIT_CODE[:load_error]
        end
      end

      def load_reporters(reporters)
        reporters.map { |option|
          class_name, arg = option.split(/(?<!:):(?!:)/, 2)
          resolve_reporter_class(class_name).new(arg:)
        }
      rescue ArgumentError => e
        puts "Bad argument to Reporter (#{e.backtrace.first}): #{e.message}"
        exit Cli::EXIT_CODE[:load_error]
      rescue LoadError => e
        puts "Loading #{file} threw an exception: #{e.class}: #{e.message}, #{e.backtrace.first}"
        exit Cli::EXIT_CODE[:load_error]
      end

      def resolve_reporter_class(reporter_name)
        [Object, Recheck::Reporter].each do |namespace|
          return namespace.const_get(reporter_name)
        rescue NameError
          next
        end
        puts "Error: Reporter class '#{reporter_name}' not found globally or in Recheck::Reporter."
        exit Cli::EXIT_CODE[:load_error]
      end
    end # Run

    class Setup
      def initialize(argv: [])
        @argv = argv
        @options = Optimist.options(@argv) do
          banner "recheck setup: create a check suite"
        end
        @files_created = []
      end

      def run
        create_helper
        create_samples
        create_site_checks
        setup_model_checks
        run_linter
        vcs_message
      end

      def run_linter
        if (linter_command = detect_linter)
          puts "Detected linter, running `#{linter_command}` on created files..."
          system("#{linter_command} #{@files_created.join(" ")}")
        end
      end

      def detect_linter
        return "bundle exec standardrb --fix-unsafely recheck" if File.exist?(".standard.yml") || gemfile_includes?("standard")
        return "bundle exec rubocop --autocorrect-all recheck" if File.exist?(".rubocop.yml") || gemfile_includes?("rubocop")
        nil
      end

      def gemfile_includes?(gem_name)
        File.readlines("Gemfile").any? { |line| line.include?(gem_name) }
      rescue Errno::ENOENT
        false
      end

      private

      def create_helper
        copy_template("#{template_dir}/recheck_helper.rb", "recheck/recheck_helper.rb")
      end

      def create_samples
        copy_template("#{template_dir}/reporter_sample.rb", "recheck/reporter/reporter.rb.sample")
        copy_template("#{template_dir}/regression_checker_sample.rb", "recheck/regression/regression_checker.rb.sample")
      end

      def create_site_checks
        Dir.glob("#{template_dir}/site/*.rb").each do |filename|
          copy_template(filename, "recheck/site/#{File.basename(filename)}")
        end
      end

      ModelFile = Data.define(:path, :class_name, :readonly, :pk_info) do
        def checker_path
          "recheck/model/#{underscore(class_name.gsub("::", "/"))}_checker.rb"
        end

        def underscore(string)
          string.gsub("::", "/")
            .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
            .gsub(/([a-z\d])([A-Z])/, '\1_\2')
            .tr("-", "_")
            .downcase
        end
      end

      # warning: the rails gem overrides this method because it can
      # provide better checks with the rails env loaded
      def setup_model_checks
        puts "Scanning for ActiveRecord models..."
        model_files.each do |mf|
          if mf.readonly
            puts "  #{mf.path} -> Skipped (readonly model, likely a view or uneditable record)"
          elsif mf.pk_info.nil?
            puts "  #{mf.path} -> Skipped (model without primary key, unable to report on it)"
          else
            FileUtils.mkdir_p(File.dirname(mf.checker_path))
            File.write(mf.checker_path, model_check_content(mf.class_name, mf.pk_info))
            @files_created << mf.checker_path
            puts "  #{mf.path} -> #{mf.checker_path}"
          end
        end
      end

      def model_files
        search_paths = Dir.glob("**/*.rb").reject { |f| f.start_with?(%r{db/migrate/|vendor/}) }
        search_paths.map do |path|
          content = File.read(path)
          if content.match?(/class\s+\w+(::\w+)*\s+<\s+(ApplicationRecord|ActiveRecord::Base)/) &&
              !content.match?(/^\s+self\.abstract_class\s*=\s*true/)
            class_name = extract_class_name(content)
            readonly = readonly_model?(content)
            pk_info = extract_primary_key_info(content)
            ModelFile.new(path, class_name, readonly, pk_info)
          end
        end.compact
      rescue Errno::ENOENT => e
        puts "Error reading file: #{e.message}"
        []
      end

      PrimaryKeyInfo = Data.define(:query_method, :fetch_id_code) do
        def compound?
          fetch_id_code.include?(" + ")
        end
      end

      def extract_primary_key_info(content)
        if content.match?(/self\.primary_key\s*=/)
          pk_definition = content.match(/self\.primary_key\s*=\s*(.+)$/)[1].strip
          if pk_definition.start_with?("[")
            keys = parse_array(pk_definition)
            fetch_id_code = keys.map { |key| "record.#{key}" }.join(' + "-" + ')
          else
            key = parse_symbol_or_string(pk_definition)
            fetch_id_code = "record.#{key}.to_s"
          end
          query_method = ".all"
        elsif content.match?(/self\.primary_key\s*=\s*nil/)
          return nil
        else
          fetch_id_code = "record.id.to_s"
          query_method = ".find_each"
        end
        PrimaryKeyInfo.new(query_method: query_method, fetch_id_code: fetch_id_code)
      end

      def parse_array(str)
        str.gsub(/[\[\]]/, "").split(",").map { |item| parse_symbol_or_string(item.strip) }
      end

      def parse_symbol_or_string(str)
        if str.start_with?(":")
          str[1..].to_sym
        elsif str.start_with?('"', "'")
          str[1..-2]
        else
          str
        end
      end

      def active_record_model?(content)
        content.match?(/class\s+\w+(::\w+)*\s+<\s+(ApplicationRecord|ActiveRecord::Base)/) &&
          !content.match?(/^\s+self\.abstract_class\s*=\s*true/) &&
          !readonly_model?(content)
      end

      def readonly_model?(content)
        content.match?(/^\s*def\s+readonly\?\s*true\s*end/) ||
          content.match?(/^\s*def\s+readonly\?\s*$\s*true\s*end/m)
      end

      def extract_class_name(content)
        content.match(/class\s+(\w+(::\w+)*)\s+</)[1]
      end

      def copy_template(from, to)
        content = File.read(from)
        FileUtils.mkdir_p(File.dirname(to))
        File.write(to, content)
        @files_created << to
        puts "Created: #{to}"
      rescue Errno::ENOENT => e
        puts "Error creating file: #{e.message}"
      end

      def model_check_content(class_name, pk_info)
        template = File.read("#{template_dir}/active_record_model_check.rb.erb")
        ERB.new(template).result(binding)
      end

      # surely there's a better way to find the gem's root
      def template_dir
        File.join(File.expand_path("../..", __dir__), "template")
      end

      def vcs_message
        puts
        puts "Run `git add --all` and `git commit` to checkpoint this setup, then `bundle exec recheck run` to check for the first time."
      end
    end # Setup
  end
end
