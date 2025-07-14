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
        model_template = File.read("#{template_dir}/application_record_check.rb.erb")
        validation_template = File.read("#{template_dir}/validation_checker.rb.erb")

        # Get all non-abstract ActiveRecord model classes
        models = ApplicationRecord.descendants.each do |model|
          puts model
          puts "  skipping abstract class" or next if model.abstract_class?
          puts "  skipping readonly model (probably a view)" or next if model.new.send(:readonly?)

          source_location = Object.const_source_location(model.to_s)
          model_root_filename = source_location[0].sub(%r{#{Rails.root}/}, "")
          # kind of a bad variable name here, but support the default model path + others
          model_filename = model_root_filename.sub(%r{^app/models/}, "")

          if %r{/zeitwerk/}.match?(source_location.first)
            puts "  Warning: model class wasn't loaded; apparently saw a zeitwerk placeholder for its source_location: #{souce_location}"
            puts "Your app boots/preloads in an unexpected way, if you can help debug please open an issue on recheck."
            exit 1
          end

          model_check_filename = "recheck/model/#{model_filename}"
          class_name = model.name.sub("::", "_") # to differentiate AccountName and Account::Name
          depth = 1 + model_filename.count("/")

          puts "  #{model_check_filename}"
          FileUtils.mkdir_p(File.dirname(model_check_filename))
          rendered = ERB.new(model_template).result_with_hash({class_name:, depth:, model:, model_root_filename:})
          File.write(model_check_filename, rendered)

          validation_check_filename = "recheck/validation/#{model_filename}"
          puts "  #{validation_check_filename}"
          FileUtils.mkdir_p(File.dirname(validation_check_filename))
          rendered = ERB.new(validation_template).result_with_hash({class_name:, depth:, model:, model_root_filename:})
          File.write(validation_check_filename, rendered)

          FileUtils.mkdir_p("recheck/regression")
        end
      end
    end
  end
end
