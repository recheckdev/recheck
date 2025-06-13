# frozen_string_literal: true

module Recheck
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
      raise ArgumentError unless [:blanket, :fail, :exception].include? type
    end
  end
end
