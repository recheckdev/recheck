class MockReporter
  attr_reader :calls

  def initialize(arg:, calls:)
    @name = arg
    @calls = calls
  end

  def around_run(kwargs, &block)
    @calls << [@name, :around_run_start]
    result = block.call
    @calls << [@name, :around_run_end]
    "#{@name} around_run return value"
  end
end

class RunnerReduceTest < Test
  def test_reduce_composes_blocks
    calls = []
    # I know I'll eventually get bit because this doesn't match the sig of Reporter::Base#initialize
    # but I need to share state between the reporters to test the order of execution.
    reporter1 = MockReporter.new(arg: :reporter1, calls:)
    reporter2 = MockReporter.new(arg: :reporter2, calls:)
    runner = Recheck::Runner.new(reporters: [reporter1, reporter2])

    # Call reduce with a block that returns our test value
    result = runner.reduce(
      hook: :around_run,
      kwargs: {test_arg: "value"},
      reporters: [reporter1, reporter2]
    ) { :expected_result }

    assert_equal :expected_result, result # not any of the reporters' block's return values

    # reporters are called in the order given, once per check
    assert_equal [
      [:reporter1, :around_run_start],
      [:reporter2, :around_run_start],
      [:reporter2, :around_run_end],
      [:reporter1, :around_run_end]
    ], calls
  end

  def test_reduce_with_empty_reporters_array
    runner = Recheck::Runner.new(reporters: [])
    result = runner.reduce(
      hook: :around_run,
      kwargs: {test_arg: "value"},
      reporters: []
    ) { :direct_result }

    assert_equal :direct_result, result
  end
end
