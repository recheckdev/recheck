# frozen_string_literal: true

class TestRecheck < Test
  def test_version_number_available_for_rails_gem
    refute_nil ::Recheck::VERSION
  end
end
