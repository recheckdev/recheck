# frozen_string_literal: true

require "active_record"

require "recheck-rails"

# AR spams stdout by default
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false

class Test < Megatest::Test
end
