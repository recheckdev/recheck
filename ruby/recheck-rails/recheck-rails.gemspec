# frozen_string_literal: true

require_relative "lib/recheck-rails/version"

Gem::Specification.new do |spec|
  spec.name = "recheck-rails"
  spec.version = Recheck::VERSION
  spec.authors = ["Peter Bhat Harkins"]
  spec.email = ["peter@recheck.coop"]

  spec.summary = "Recheck your production data integrity"
  spec.description = "Check on validations, background jobs, third-party integrations, state machines, and business rules"
  spec.homepage = "https://recheck.dev"
  spec.license = "LGPL-3.0"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/recheckdev/recheck/ruby/recheck-rails"
  spec.metadata["changelog_uri"] = "https://github.com/recheckdev/recheck/ruby/recheck-rails/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github Gemfile])
    end
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # runtime dependencies here
  spec.add_dependency "recheck"
end
