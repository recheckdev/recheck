require "rails"
require "recheck"

module Recheck
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.expand_path("../tasks/recheck_tasks.rake", __FILE__)
    end
  end
end
