# Decorates a Check::V1 to call reporters.
module Recheck
  class WithReporters
    def initialize(check_class, reporters: [])
      @check_class = check_class
      @reporters = reporters
    end

    def run(notify)
      check = @check_class.new
      class_counts = CountStats.new
      @reporters.each { |r| r.before_check_class_run(@check_class, @check_class.check_methods) }

      check.run(notify) do |check_method, result|
        class_counts.increment(result.type)

        @reporters.each { |r| r.check_result(@check_class, check_method, result) }

        # if the first 20 error out, skip the check, it's probably buggy
        if class_counts.reached_blanket_failure?
          blanket = Error.new(check_class: check.class, check_method: check_method, record: nil, type: :blanket, exception: nil)
          check.notify(blanket)
          @reporters.each { |r| r.check_result(@check_class, check_method, blanket) }
          break
        end
      end

      @reporters.each { |r| r.after_check_class_run(@check_class, class_counts) }
      class_counts
    end
  end
end
