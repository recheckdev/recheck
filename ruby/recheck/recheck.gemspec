# frozen_string_literal: true

require_relative "lib/recheck/version"

Gem::Specification.new do |spec|
  spec.name = "recheck"
  spec.version = Recheck::VERSION
  spec.authors = ["Peter Bhat Harkins"]
  spec.email = ["peter@recheck.coop"]

  spec.summary = "Recheck your production data integrity"
  spec.description = "Check on validations, background jobs, third-party integrations, state machines, and business rules"
  spec.homepage = "https://recheck.dev"
  spec.license = "LGPL-3.0"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/recheckdev/recheck/ruby/recheck"
  spec.metadata["changelog_uri"] = "https://github.com/recheckdev/recheck/ruby/recheck/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `find . -type f -print0`.split("\x0").select { |f| f.match?(/\.rb$/) }.map { |f| f.sub(/\A\.\//, '') }.reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github Gemfile])
    end
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # runtime dependencies here
  spec.add_dependency "resolv"
  spec.add_dependency "whois", "~> 5.1"
  spec.add_dependency "whois-parser"
end
