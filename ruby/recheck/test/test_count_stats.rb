# frozen_string_literal: true

class TestCountStats < Test
  def test_initialization
    stats = Recheck::CountStats.new
    assert_equal 0, stats.pass
    assert_equal 0, stats.fail
    assert_equal 0, stats.exception
    assert_equal 0, stats.total
  end

  def test_increment
    stats = Recheck::CountStats.new
    stats.increment(:pass)
    assert_equal 1, stats.pass
    assert_equal 0, stats.fail
    assert_equal 0, stats.exception

    stats.increment(:fail)
    assert_equal 1, stats.pass
    assert_equal 1, stats.fail
    assert_equal 0, stats.exception

    stats.increment(:exception)
    assert_equal 1, stats.pass
    assert_equal 1, stats.fail
    assert_equal 1, stats.exception

    assert_equal 3, stats.total
  end

  def test_increment_with_invalid_type
    stats = Recheck::CountStats.new
    assert_raises(ArgumentError) do
      stats.increment(:invalid_type)
    end
  end

  def test_all_pass
    stats = Recheck::CountStats.new
    assert stats.all_pass?

    stats.increment(:pass)
    assert stats.all_pass?

    stats.increment(:fail)
    refute stats.all_pass?

    stats = Recheck::CountStats.new
    stats.increment(:exception)
    refute stats.all_pass?
  end

  def test_all_zero
    stats = Recheck::CountStats.new
    assert stats.all_zero?

    stats.increment(:pass)
    refute stats.all_zero?

    stats = Recheck::CountStats.new
    stats.increment(:fail)
    refute stats.all_zero?

    stats = Recheck::CountStats.new
    stats.increment(:exception)
    refute stats.all_zero?
  end

  def test_reached_blanket_failure_with_fails
    stats = Recheck::CountStats.new
    refute stats.reached_blanket_failure?

    19.times { stats.increment(:fail) }
    refute stats.reached_blanket_failure?

    stats.increment(:fail)
    assert stats.reached_blanket_failure?
  end

  def test_reached_blanket_failure_with_exceptions
    stats = Recheck::CountStats.new
    refute stats.reached_blanket_failure?

    19.times { stats.increment(:exception) }
    refute stats.reached_blanket_failure?

    stats.increment(:exception)
    assert stats.reached_blanket_failure?
  end

  def test_dont_reach_blanket_failure_with_passes
    stats = Recheck::CountStats.new
    20.times { stats.increment(:fail) }
    assert stats.reached_blanket_failure?

    stats.increment(:pass)
    refute stats.reached_blanket_failure?
  end

  def test_merge_operator
    stats1 = Recheck::CountStats.new
    stats1.increment(:pass)
    stats1.increment(:fail)

    stats2 = Recheck::CountStats.new
    stats2.increment(:pass)
    stats2.increment(:exception)

    result = stats1 << stats2

    assert_equal 2, stats1.pass
    assert_equal 1, stats1.fail
    assert_equal 1, stats1.exception
    assert_equal 4, stats1.total
  end
end
