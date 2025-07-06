class UnyieldingReporter < Recheck::Reporter::Base
  def initialize(arg:)
    @skip = arg
  end

  def around_run **kwargs
    yield unless @skip == :around_run
  end

  def around_checker **kwargs
    yield unless @skip == :around_checker
  end

  def around_check **kwargs
    yield unless @skip == :around_check
  end
end

class YieldChecker < Recheck::Checker::Base
  def query
    [1]
  end

  def check_example *args
  end
end

class RunnerYieldTest < Test
  def test_runner_recognizes_reporter_failed_to_yield_around_run
    reporter = UnyieldingReporter.new(arg: :around_run)
    runner = Recheck::Runner.new(reporters: [reporter])

    assert_raises(Recheck::HookDidNotYield) do
      runner.run
    end
  end

  def test_runner_recognizes_reporter_failed_to_yield_around_checker
    reporter = UnyieldingReporter.new(arg: :around_checker)
    runner = Recheck::Runner.new(reporters: [reporter], checkers: [YieldChecker.new])

    assert_raises(Recheck::HookDidNotYield) do
      runner.run
    end
  end

  def test_runner_recognizes_reporter_failed_to_yield_around_check
    reporter = UnyieldingReporter.new(arg: :around_check)
    runner = Recheck::Runner.new(reporters: [reporter], checkers: [YieldChecker.new])

    assert_raises(Recheck::HookDidNotYield) do
      runner.run
    end
  end
end
