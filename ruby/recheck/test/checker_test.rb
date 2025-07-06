require_relative "test_helper"

class CheckerTest < Test
  def test_query_methods_reflection
    test_checker = Class.new(Recheck::Checker::Base) do
      def query_users
      end

      def not_a_query
      end
    end

    query_methods = test_checker.query_methods
    assert_includes query_methods, :query_users
    refute_includes query_methods, :not_a_query
  end

  def test_check_methods_reflection
    test_checker = Class.new(Recheck::Checker::Base) do
      def check_valid(record)
      end

      def not_a_check(record)
      end
    end

    check_methods = test_checker.check_methods
    assert_includes check_methods, :check_valid
    refute_includes check_methods, :not_a_check
  end

  def test_subclassing_registers_checker
    original_subclasses = Recheck::Checker::Base.checker_classes.dup

    test_checker = Class.new(Recheck::Checker::Base) do
      def query
      end

      def check_test(record)
      end
    end

    assert_includes Recheck::Checker::Base.checker_classes, test_checker

    Recheck::Reporter::Base.instance_variable_set(:@subclasses, original_subclasses)
  end

  def test_register_non_inheriting_class
    original_subclasses = Recheck::Checker::Base.checker_classes.dup

    oddball_checker = Class.new

    Recheck::Checker::Base.register(oddball_checker)

    assert_includes Recheck::Checker::Base.checker_classes, oddball_checker

    Recheck::Reporter::Base.instance_variable_set(:@subclasses, original_subclasses)
  end
end
