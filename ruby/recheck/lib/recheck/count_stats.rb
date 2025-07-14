module Recheck
  class CountStats
    attr_reader :counts, :queries

    Recheck::RESULT_TYPES.each do |type|
      define_method(type) do
        @counts[type]
      end
    end

    def initialize
      @counts = RESULT_TYPES.map { [it, 0] }.to_h
      @queries = 0
    end

    def <<(other)
      @queries += other.queries
      @counts.merge!(other.counts) { |type, self_v, other_v| self_v + other_v }
      self
    end

    def all_pass?
      @counts.slice(*Recheck::ERROR_TYPES).all? { |type, count| count.zero? }
    end

    def all_zero?
      @counts.all? { |type, count| count.zero? }
    end

    def any_errors?
      !all_pass?
    end

    def increment(type)
      if type == :queries
        @queries += 1
      elsif !@counts.include? type
        raise ArgumentError, "Unkown type #{type}"
      else
        @counts[type] += 1
      end
    end

    def reached_blanket_failure?
      pass == 0 && (fail == 20 || exception == 20)
    end

    def summary
      "#{queries} #{(queries == 1) ? "query" : "queries"}, " + (
        [:pass, :fail] +
        [
          :exception,
          :blanket,
          :no_query_methods,
          :no_queries,
          :no_check_methods,
          :no_checks
        ].filter { |type| @counts[type].nonzero? }
      ).map { |type| "#{@counts[type]} #{type}" }.join(", ")
    end

    def total
      @counts.values.sum
    end
  end
end
