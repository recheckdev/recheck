module Recheck
  module Command
    class Reporters
      def initialize(argv)
        Optimist.options(argv) do
          banner "recheck list_reporters: load and list reporters"
        end
      end

      def run
        puts "Available reporters (add yours to recheck/reporter/):"
        Recheck::Reporter::Base.subclasses.each do |reporter_class|
          help = reporter_class.respond_to?(:help) ? reporter_class.help : nil
          help ||= "No help avalable"
          puts "  #{reporter_class.name}   #{help}"
        end
        puts
        puts "`recheck run --reporter` falls back to the `Recheck::Reporter` namespace so you can name `--reporter Json`"
      end
    end
  end
end
