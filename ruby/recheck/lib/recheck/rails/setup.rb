require "pathname"

require "erb"

require_relative "validation"

module Recheck
  module Command
    class Setup
      # override the base gem's method; with the Rails env booted we can
      # introspect the models to create much better initial checks
      def setup_model_checks
        puts "Introspecting ApplicationRecord..."

        # surely there's a better way to find the gem's root
        template_dir = File.join(File.expand_path("../../..", __dir__), "template")
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
          binding = Validation.new(class_name:, depth:, model:, model_root_filename:, queries: queries(model:)).get_binding
          rendered = ERB.new(validation_template, trim_mode: "-").result(binding)
          File.write(validation_check_filename, rendered)
        end
      end

      def queries model:
        model.validators.map do |validator|
          # validators take a list of attributes but operate on them individually
          validator.attributes.map do |attr|
            name = "query_#{validator.kind}_#{attr}"
            # remove memory addresses; just noise
            inspect = validator.inspect.gsub(/(#<[\w:]+):0x[0-9a-f]+ /, '\1 ')

            column = model.columns_hash[attr.to_s]
            next Placeholder.new inspect:, comment: "Can't query attribute #{attr}, it's not a database column" if column.nil?
            type = column.sql_type_metadata.type

            if validator.options[:if] || validator.options[:unless]
              next Placeholder.new inspect:, comment: "Can't automatically translate this validation's :if or :unless into a query"
            end

            # normalizing - if not specified or [], on: means [:create, :udpate]
            on = validator.options[:on] || []
            on = [:create, :update] if on.empty?
            if validator.options[:on] == [:create]
              next Placeholder.new inspect:, comment: "Only validates on: :create, so there's nothing to validate for persisted records"
            end

            warning = if validator.options[:allow_nil] && !column.null
              "Warning: model #{model.name} validates #{attr} with :allow_nil but column #{column.name} is NOT NULL, so a 'valid' record can't be saved.\nRemove :allow_nil or make the column nullable."
            end

            case validator
            when ActiveModel::BlockValidator
              Placeholder.new inspect:, comment: "Can't automatically translate a Ruby block into a query."
            when ActiveModel::Validations::ConfirmationValidator
              FunctionPlaceholder.new inspect:, name:, comment: "Coming soon to Recheck beta"
            when ActiveModel::Validations::FormatValidator
              FunctionPlaceholder.new inspect:, name:, comment: "Coming soon to Recheck beta"
            when ActiveModel::Validations::InclusionValidator
              FunctionPlaceholder.new inspect:, name:, comment: "Coming soon to Recheck beta"
            when ActiveRecord::Validations::AbsenceValidator
              FunctionPlaceholder.new inspect:, name:, comment: "Coming soon to Recheck beta"
            when ActiveRecord::Validations::AssociatedValidator
              FunctionPlaceholder.new inspect:, name:, comment: "Coming soon to Recheck beta"
            when ActiveRecord::Validations::LengthValidator
              or_clauses = []
              if type == :string || type == :text || type == :integer
                if validator.options[:is]
                  or_clauses << %{"LENGTH(`#{column.name}`) = '')"}
                end
                if validator.options[:minimum] && validator.options[:maximum]
                  or_clauses << %{"LENGTH(`#{column.name}`) < #{validator.options[:minimum]} and LENGTH(`#{column.name}`) > #{validator.options[:maximum]}"}
                elsif validator.options[:minimum]
                  or_clauses << %{"LENGTH(`#{column.name}`) < #{validator.options[:minimum]}"}
                elsif validator.options[:maximum]
                  or_clauses << %{"LENGTH(`#{column.name}`) > #{validator.options[:maximum]}"}
                end
              elsif type == :boolean
                comment = "Validating length of a boolean is backend-dependent and a strange idea."
              else
                comment = "Recheck doesn't know how to handle length on a #{type}, please report."
              end
              if !validator.options[:allow_nil] && !validator.options[:allow_blank]
                or_clauses << "#{column.name}: nil"
              end
              Query.new inspect:, name:, warning:, comment:, or_clauses:
            when ActiveRecord::Validations::NumericalityValidator
              FunctionPlaceholder.new inspect:, name:, comment: "Coming soon to Recheck beta"
            when ActiveRecord::Validations::PresenceValidator
              if validator.options[:allow_blank]
                next Placeholder.new inspect:, comment: "Validates presence of #{attr} with :allow_blank, which can never fail."
              end
              or_clauses = []
              if !validator.options[:allow_nil]
                or_clauses << "#{column.name}: nil"
              end
              case type
              when :string
                or_clauses << %{"TRIM(`#{column.name}`) = ''"}
              when :boolean
                or_clauses << "#{column.name}: false"
              else
                comment = "Recheck doesn't know how to handle presence on a #{type}, please report."
              end
              Query.new inspect:, name:, warning:, comment:, or_clauses:
            when ActiveRecord::Validations::UniquenessValidator
              FunctionPlaceholder.new inspect:, name:, comment: "Coming soon to Recheck beta"
            end
          end
        end.flatten
      end
    end
  end
end
