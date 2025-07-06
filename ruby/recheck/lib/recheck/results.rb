# frozen_string_literal: true

module Recheck
  ERROR_TYPES = [:fail, :exception, :blanket, :no_query_methods, :no_queries, :no_check_methods, :no_checks].freeze
  RESULT_TYPES = ([:pass] + ERROR_TYPES).freeze

  # This doesn't track all the fields because Recheck is about finding errors and failures.
  # If you need more data, please tell me about your use case?
  Success = Data.define do
    def type
      :pass
    end
  end

  Error = Data.define(:checker, :check, :record, :type, :exception) do
    def initialize(*args)
      super
      raise ArgumentError unless ERROR_TYPES.include? type
    end
  end
end
