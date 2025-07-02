require "pathname"

require "erb"

module Recheck
  module Command
    class Setup
      # override the base gem's method; with the Rails env booted we can
      # introspect the models to create much better initial checks
      def setup_model_checks
        puts "Introspecting ApplicationRecord..."

        # surely there's a better way to find the gem's root
        template_dir = File.join(File.expand_path("../..", __dir__), "template")
        template = File.read("#{template_dir}/application_record_check.rb.erb")

        # Get all non-abstract ActiveRecord model classes
        models = ApplicationRecord.descendants.each do |model|
          print "#{model} "
          puts "skipping abstract class" or next if model.abstract_class?
          puts "skipping readonly model (probably a view)" or next if model.new.send(:readonly?)

          source_location = Object.const_source_location(model.to_s)
          model_filename = source_location[0].sub(%r{#{Rails.root}}, "").sub(%r{^/app/models/}, "")
          if %r{/zeitwerk/}.match?(source_location.first)
            puts "  Warning: model class wasn't loaded; apparently saw a zeitwerk placeholder for its source_location: #{souce_location}"
            puts "Your app boots/preloads in an unexpected way, if you can help debug please open an issue on recheck."
            exit 1
          end

          # pluralize dir because an old enough mistake is called a "convention"
          check_filename = "recheck/models/#{model_filename}"
          class_name = model.name.sub("::", "_") # to differentiate AccountName and Account::Name
          depth = 1 + model_filename.count("/")

          puts "  #{check_filename}"
          FileUtils.mkdir_p(File.dirname(check_filename))
          rendered = ERB.new(template).result_with_hash({class_name:, depth:, model:})
          File.write(check_filename, rendered)

          FileUtils.mkdir_p("recheck/regression")
        end
      end
    end
  end
end
