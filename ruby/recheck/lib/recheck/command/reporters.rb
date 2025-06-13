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
          name = reporter_class.name.sub(/^Recheck::Reporter::/, "")
          help = reporter_class.respond_to?(:help) ? reporter_class.help : nil
          help ||= "No help avalable"
          puts "  #{name}: #{help}"
        end
      end
    end
  end
end
