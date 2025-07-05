require_relative "test_helper"

# Mock class for testing
class TestRecord
  def to_s
    "test_record_42"
  end
end

class CheckerTest < Test
  def setup
    @test_record = TestRecord.new
  end

  def test_subclassing_registers_checker
    original_checker_classes = Recheck::Checker::Base.checker_classes.dup
    
    test_checker = Class.new(Recheck::Checker::Base) do
      def query
        [1, 2, 3]
      end
      
      def check_test(record)
        true
      end
    end
    
    assert_includes Recheck::Checker::Base.checker_classes, test_checker
    
    # Cleanup
    Recheck::Checker::Base.checker_classes.subtract([test_checker])
    assert_equal original_checker_classes, Recheck::Checker::Base.checker_classes
  end
  
  def test_query_methods_reflection
    test_checker = Class.new(Recheck::Checker::Base) do
      def query_users
        []
      end
      
      def query_orders
        []
      end
      
      def not_a_query
        []
      end
    end
    
    query_methods = test_checker.query_methods
    assert_includes query_methods, :query_users
    assert_includes query_methods, :query_orders
    refute_includes query_methods, :not_a_query
  end
  
  def test_check_methods_reflection
    test_checker = Class.new(Recheck::Checker::Base) do
      def check_valid(record)
        true
      end
      
      def check_has_email(record)
        true
      end
      
      def not_a_check(record)
        true
      end
    end
    
    check_methods = test_checker.check_methods
    assert_includes check_methods, :check_valid
    assert_includes check_methods, :check_has_email
    refute_includes check_methods, :not_a_check
  end
  
  def test_register_non_inheriting_class
    original_checker_classes = Recheck::Checker::Base.checker_classes.dup
    
    # Create a class that doesn't inherit from Base
    standalone_checker = Class.new do
      def query
        []
      end
      
      def check_test(record)
        true
      end
    end
    
    # Register it manually
    Recheck::Checker::Base.register(standalone_checker)
    
    assert_includes Recheck::Checker::Base.checker_classes, standalone_checker
    
    # Cleanup
    Recheck::Checker::Base.checker_classes.subtract([standalone_checker])
    assert_equal original_checker_classes, Recheck::Checker::Base.checker_classes
  end
end
