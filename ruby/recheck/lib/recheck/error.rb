# frozen_string_literal: true

module Recheck
  # All happy families are alike; each unhappy family is unhappy in its own way.
  Success = Data.define do
    def type
      :pass
    end
  end

  Error = Data.define(:checker_class, :check, :record, :type, :exception) do
    def initialize(*args)
      super
      raise ArgumentError unless [:blanket, :fail, :exception].include? type
    end
  end
end
