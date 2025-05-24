module Recheck
  class CountStats
    attr_reader :pass, :fail, :exception

    def initialize
      @pass = 0
      @fail = 0
      @exception = 0
    end

    def <<(other)
      @pass += other.pass
      @fail += other.fail
      @exception += other.exception
    end

    def all_pass?
      fail == 0 && exception == 0
    end

    def all_zero?
      pass == 0 && fail == 0 && exception == 0
    end

    def increment(type)
      case type
      when :pass then @pass += 1
      when :fail then @fail += 1
      when :exception then @exception += 1
      else raise ArgumentError, "Unkown type #{type}"
      end
    end

    def reached_blanket_failure?
      pass == 0 && (fail == 20 || exception == 20)
    end

    def total
      @pass + @fail + @exception
    end
  end
end
