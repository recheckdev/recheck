require "erb"

module Recheck
  class Setup
    def initialize
      @files_created = []
    end

    def self.run
      new.run
    end

    def run
      create_check_helper
      create_reporter_dir
      create_site_checks
      setup_model_checks
      run_linter

      puts
      puts "Run `git add --all` and `git commit` to checkpoint this setup, then `bundle exec recheck` to check for the first time."
    end

    def run_linter
      if (linter_command = detect_linter)
        puts "Detected linter, running `#{linter_command}` on created files..."
        system("#{linter_command} #{@files_created.join(" ")}")
      end
    end

    def detect_linter
      return "bundle exec standardrb --fix-unsafely" if File.exist?(".standard.yml") || gemfile_includes?("standard")
      return "bundle exec rubocop --autocorrect-all" if File.exist?(".rubocop.yml") || gemfile_includes?("rubocop")
      nil
    end

    def gemfile_includes?(gem_name)
      File.readlines("Gemfile").any? { |line| line.include?(gem_name) }
    rescue Errno::ENOENT
      false
    end

    private

    def create_check_helper
      copy_template("#{template_dir}/check_helper.rb", "recheck/check_helper.rb")
    end

    def create_reporter_dir
      FileUtils.mkdir_p("recheck/reporter")
    end

    def create_site_checks
      Dir.glob("#{template_dir}/site/*.rb").each do |filename|
        copy_template(filename, "recheck/site/#{File.basename(filename)}")
      end
    end

    ModelFile = Data.define(:path, :class_name, :readonly, :pk_info) do
      def check_path
        "recheck/model/#{underscore(class_name.gsub("::", "/"))}_check.rb"
      end

      def underscore(string)
        string.gsub("::", "/")
          .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .tr("-", "_")
          .downcase
      end
    end

    def setup_model_checks
      puts "Scanning for ActiveRecord models..."
      model_files.each do |mf|
        if mf.readonly
          puts "  #{mf.path} -> Skipped (readonly model, likely a view or uneditable record)"
        elsif mf.pk_info.nil?
          puts "  #{mf.path} -> Skipped (model without primary key, unable to report on it)"
        else
          FileUtils.mkdir_p(File.dirname(mf.check_path))
          File.write(mf.check_path, model_check_content(mf.class_name, mf.pk_info))
          @files_created << mf.check_path
          puts "  #{mf.path} -> #{mf.check_path}"
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
  end
end
