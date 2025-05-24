# frozen_string_literal: true

require_relative "recheck/check/v1"
require_relative "recheck/cli"
require_relative "recheck/count_stats"
require_relative "recheck/reporter/base_reporter"
require_relative "recheck/reporter/default_reporter"
require_relative "recheck/reporter/json_reporter"
require_relative "recheck/results"
require_relative "recheck/setup"
require_relative "recheck/version"
require_relative "recheck/with_reporters"

module Recheck
  # Check if an obj.is_a? Foo without having to depend on or load the foo gem.
  def self.unloaded_is_a? obj, class_name
    raise ArgumentError, "unloaded_is_a? takes class_name as a String" unless class_name.is_a? String

    Object.const_defined?(class_name) && obj.is_a?(Object.const_get(class_name))
  end
end
