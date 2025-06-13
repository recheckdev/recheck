module Recheck
  class Cli
    EXIT_CODE = {
      no_errors: 0,  # all checks passed
      any_errors: 1, # any check returns fail or threw an exception
      run_errors: 2  # recheck itself encountered an error
    }

    COMMANDS = {
      reporters: "List available reporters",
      run: "Run checks",
      setup: "Set up a new check suite in the current directory"
    }

    def initialize(argv)
      @argv = argv
    end

    def run
      global_options = Recheck::Optimist.options(@argv) do
        version "recheck v#{Recheck::VERSION}"

        banner "Usage:"
        banner "  recheck [global options] [<command> [options]]"

        banner "\nGlobal options:"
        opt :version, "Print version and exit", short: :v
        opt :help, "Print help", short: :h
        stop_on COMMANDS.keys.map(&:to_s)

        banner "\nCommands:"
        COMMANDS.each { |c, desc| banner format("  %-10s %s", c, desc) }
      end

      command = global_options[:_leftovers].shift&.to_sym || :help
      Recheck::Optimist.die "unknown command '#{command}'" unless COMMANDS.include? command

      command_class = command.to_s.split("_").map(&:capitalize).join("")
      Recheck::Command.const_get(command.to_s.split("_").map(&:capitalize).join("")).new(global_options[:_leftovers]).run

      exit EXIT_CODE[:no_errors]
    rescue Interrupt
      puts "\nOperation cancelled by user."
      exit EXIT_CODE[:run_errors]
    end
  end
end
