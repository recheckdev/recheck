# frozen_string_literal: true

class TestResults < Test
  def test_success_type
    success = Recheck::Success.new
    assert_equal :pass, success.type
  end

  def test_error_initialization_with_invalid_type
    assert_raises(ArgumentError) do
      Recheck::Error.new(
        checker: Object.new,
        check: :check_something,
        record: {id: 123},
        type: :invalid_type,
        exception: nil
      )
    end
  end
end
