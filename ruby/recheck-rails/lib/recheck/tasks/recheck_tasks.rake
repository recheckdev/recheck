namespace :recheck do
  desc "Set up a recheck suite"
  task setup: :environment do
    # Eager load all models for introspection
    Rails.application.eager_load!

    require "recheck/commands"
    require "recheck-rails/setup"

    Recheck::Command::Setup.new(argv: []).run
  end

  desc "Run recheck checks"
  task :run, [:args] => :environment do |_t, args|
    require "recheck/commands"

    Recheck::Command::Run.new(argv: args[:args]&.split || []).run
  end
end
