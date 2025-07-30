module Recheck
  Placeholder = Data.define(:inspect, :comment)
  FunctionPlaceholder = Data.define(:inspect, :name, :comment)
  Query = Data.define(:inspect, :warning, :name, :comment, :or_clauses)

  Validation = Data.define(:class_name, :depth, :model, :model_root_filename, :queries) do
    def get_binding
      binding
    end
  end
end
