module Recheck
  module Reporter
    class Json < Base
      def self.help
        "Outputs JSON-formatted results to a file or stdout. Arg is filename or blank for stdout."
      end

      def initialize(arg:)
        @filename = arg
        @results = {}
      end

      def around_checker(checker:, checks: [])
        @results[checker.to_s] = checks.to_h { |method|
          [method, {
            counts: CountStats.new,
            fail: [],
            exception: []
          }]
        }
        yield
      end

      def around_check(checker:, checks:)
        result = yield

        @results[checker.class.to_s][check][:counts].increment(result.type)
        case result.type
        when :fail
          @results[checker.class.to_s][check][:fail] << fetch_record_id(result.record)
        when :exception
          @results[checker.class.to_s][check][:exception] << {
            id: fetch_record_id(result.record),
            message: result.exception.message,
            backtrace: result.exception.backtrace
          }
        when :blanket
          @results[checker.class.to_s][check][:blanket] = true
        end

        if @filename
          File.write(@filename, @results.to_json)
        else
          puts @results.to_json
        end
      end
    end
  end
end
