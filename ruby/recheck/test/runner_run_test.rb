require_relative "test_helper"

class MockReporter < Recheck::Checker::Base
  attr_reader :name, :calls

  def initialize(arg:, calls:)
    @name = arg
    @calls = calls
  end

  def around_run(kwargs, &block)
    @calls << [@name, :around_run_start, kwargs[:checkers].map(&:name)]
    result = block.call
    @calls << [@name, :around_run_end] # , result]
    result
  end

  def around_checker(kwargs, &block)
    @calls << [@name, :around_checker_start, kwargs[:checker].name]
    result = block.call
    @calls << [@name, :around_checker_end, result]
    result
  end

  def around_query(kwargs, &block)
    @calls << [@name, :around_query_start, kwargs[:check], kwargs[:record]]
    result = block.call
    @calls << [@name, :around_query_end, result]
    result
  end

  def around_check(kwargs, &block)
    @calls << [@name, :around_check_start, kwargs[:check], kwargs[:record]]
    result = block.call
    @calls << [@name, :around_check_end, result]
    result
  end
end

class MockChecker < Recheck::Checker::Base
  attr_reader :name, :calls

  def initialize(name:, calls:)
    @name = name
    @calls = calls
  end

  def query_test
    @calls << [@name, :query_test]
    [1, 2]  # two test records
  end

  def check_test(record)
    @calls << [@name, :check_test, record]
    true
  end
end

class RunnerRunTest < Test
  def test_run_executes_in_correct_order
    calls = []
    checker1 = MockChecker.new(name: :checker1, calls: calls)
    checker2 = MockChecker.new(name: :checker2, calls: calls)
    reporter1 = MockReporter.new(arg: :reporter1, calls: calls)
    reporter2 = MockReporter.new(arg: :reporter2, calls: calls)
    runner = Recheck::Runner.new(
      checkers: [checker1, checker2],
      reporters: [reporter1, reporter2]
    )

    result = runner.run
    # puts calls.map(&:to_s).join("\n")

    assert_instance_of Recheck::CountStats, result
    # puts result.inspect

    # reporters wrap each other, so it's 1 2 (work) 2 1
    assert_equal [
      [:reporter1, :around_run_start, [:checker1, :checker2]],
      [:reporter2, :around_run_start, [:checker1, :checker2]]
    ], calls[0..1]
    assert_equal [
      [:reporter2, :around_run_end],
      [:reporter1, :around_run_end]
    ], calls[-2..]

    # each checker's query_test is called exactly once
    # puts calls.inspect
    assert_equal 1, calls.count { |c| c[0] == :checker1 && c[1] == :query_test }
    assert_equal 1, calls.count { |c| c[0] == :checker2 && c[1] == :query_test }

    # each checker's check_test was called twice (once for each record)
    assert_equal 2, calls.count { |c| c[0] == :checker1 && c[1] == :check_test }
    assert_equal 2, calls.count { |c| c[0] == :checker2 && c[1] == :check_test }

    # around_check was called 2 reporters * 2 checkers * 2 records
    assert_equal 8, calls.count { |c| c[1] == :around_check_start }

    # around_checker was called 2 reporters * 2 checkers
    assert_equal 4, calls.count { |c| c[1] == :around_checker_start }

    assert_equal 4, result.pass # 2 checkers * 2 records, all pass
    assert_equal 0, result.fail
    assert_equal 0, result.exception
  end
end
