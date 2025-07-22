require "test_helper"

module ActiveRecord
  class Base
  end
end

class ReporterTestModel < ActiveRecord::Base
  def id
    42
  end
end

class TestChecker; end

class ReporterTest < Test
  def setup
    @test_record = ReporterTestModel.new
    @test_checker = TestChecker.new

    @mock_error = Recheck::Error.new(
      checker: @test_checker,
      query: :query,
      check: :check_test,
      record: @test_record,
      type: :fail,
      exception: nil
    )
  end

  def test_base_reporter_fetch_record_id
    reporter = Recheck::Reporter::Base.new(arg: nil)
    assert_equal "42", reporter.fetch_record_id(@test_record)
  end

  def test_subclassing_registers_reporter
    original_subclasses = Recheck::Reporter::Base.subclasses.dup

    test_reporter = Class.new(Recheck::Reporter::Base) do
      def self.help
        "Registration test reporter"
      end
    end

    assert_includes Recheck::Reporter::Base.subclasses, test_reporter

    Recheck::Reporter::Base.instance_variable_set(:@subclasses, original_subclasses)
  end
end
