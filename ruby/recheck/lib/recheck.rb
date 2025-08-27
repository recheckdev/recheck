# frozen_string_literal: true

module Recheck
  # Check if an obj.is_a? Foo without having to depend on or load the foo gem.
  def self.unloaded_is_a? obj, class_name
    raise ArgumentError, "unloaded_is_a? takes class_name as a String" unless class_name.is_a? String

    Object.const_defined?(class_name) && obj.is_a?(Object.const_get(class_name))
  end
end

require "recheck/vendor/optimist"
require "recheck/checkers"
require "recheck/cli"
require "recheck/commands"
require "recheck/results"
require "recheck/count_stats"
require "recheck/reporters"
require "recheck/runner"
require "recheck/version"

require "recheck/rails/railtie" if defined?(::Rails)
