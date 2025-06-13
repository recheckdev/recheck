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

      def around_check_class_run(check_class:, check_methods: [])
        @results[check_class.to_s] = check_methods.to_h { |method|
          [method, {
            counts: CountStats.new,
            fail: [],
            exception: []
          }]
        }
        yield
      end

      def around_check(check_class:, check_method:)
        result = yield

        @results[check_class.to_s][check_method][:counts].increment(result.type)
        case result.type
        when :fail
          @results[check_class.to_s][check_method][:fail] << fetch_record_id(result.record)
        when :exception
          @results[check_class.to_s][check_method][:exception] << {
            id: fetch_record_id(result.record),
            message: result.exception.message,
            backtrace: result.exception.backtrace
          }
        when :blanket
          @results[check_class.to_s][check_method][:blanket] = true
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
