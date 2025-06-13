module Recheck
  module Reporter
    class Silent < Base
      def self.help
        "Prints nothing. Useful for checks that can automatically fix issues."
      end

      def initialize(arg:)
        raise ArgumentError, "does not take options" unless arg.nil?
      end
    end
  end
end
