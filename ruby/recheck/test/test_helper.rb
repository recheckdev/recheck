# frozen_string_literal: true

require "active_record"

require "recheck"

# AR spams stdout by default
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false

class Test < Megatest::Test
  setup do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
  end
end
