# Decorates a Check::V1 to call reporters.
module Recheck
  class WithReporters
    def initialize(check_class, reporters: [])
      @check_class = check_class
      @reporters = reporters
    end

    def run
      check = @check_class.new

      class_counts = CountStats.new

      @reporters.each do |reporter|
        reporter.around_check_class_run(check_class: @check_class, check_methods: @check_class.check_methods) do
          check.run do |check_method, result|
            @reporters.each do |r|
              r.around_check(check_class: @check_class, check_method: check_method) { result }
            end

            class_counts.increment(result.type)

            # if the first 20 error out, skip the check, it's probably buggy
            if class_counts.reached_blanket_failure?
              blanket = Error.new(check_class: check.class, check_method: check_method, record: nil, type: :blanket, exception: nil)
              @reporters.each do |r|
                r.around_check(check_class: @check_class, check_method: check_method) { blanket }
              end
              break
            end
          end

          class_counts
        end
      end

      class_counts
    end
  end
end
