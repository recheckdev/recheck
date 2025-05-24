module Recheck
  module Reporter
    class JsonReporter < BaseReporter
      def self.help
        "JSON reporter that outputs results to a file or stdout. Takes json argument for filename; defaults to stdout: {\"filename\": \"path/to/output.json\"}"
      end

      def initialize(arg)
        @results = {}
        @total_counts = CountStats.new

        options = arg ? JSON.parse(arg) : {}
        @filename = options["filename"]
        raise ArgumentError, "JsonReporter only accepts 'filename' as an argument" if options.keys.any? { |k| k != "filename" }
      rescue JSON::ParserError => e
        raise ArgumentError, "Invalid json: #{e.message}"
      end

      def before_run
      end

      def before_check_class_run(check_class, check_methods)
        @results[check_class.to_s] = check_methods.to_h { |method|
          [method, {
            counts: CountStats.new,
            fail: [],
            exception: []
          }]
        }
      end

      def check_result(check_class, check_method, result)
        @results[check_class.to_s][check_method][:counts].increment(result.type)
        case result.type
        when :fail
          @results[check_class.to_s][check_method][:fail] << result.check_class.fetch_record_id(result.record)
        when :exception
          @results[check_class.to_s][check_method][:exception] << {
            id: result.check_class.fetch_record_id(result.record),
            message: result.exception.message,
            backtrace: result.exception.backtrace
          }
        when :blanket
          @results[check_class.to_s][check_method][:blanket] = true
        end
      end

      def after_check_class_run(check_class, class_counts)
      end

      def after_run(total_counts)
        @total_counts = total_counts
        if @filename
          File.write(@filename, @results.to_json)
        else
          puts @results.to_json
        end
      end
    end
  end
end
