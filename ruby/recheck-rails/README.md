# Recheck-Rails

[Recheck](https://recheck.dev) is a tool for checking the correctness of production data.

This gem contains Rails-specific checks and features.
To use Recheck on a Rails app, add it to your `Gemfile`:

    gem "recheck-rails"

Recheck runs against production data, so don't put it only in a `development` or `test` group like a testing tool.

Generate basic checks based on your existing models with:

    bundle exec rails recheck:setup

See the [recheck gem README](https://github.com/recheckdev/ruby/recheck) to see
how to run and expand your suite of checks.


## Contributing

Bug reports, feature requests, and pull requests are welcome on GitHub at: https://github.com/recheckdev/recheck

After checking out the repo, run `bin/setup` to install dependencies.
Then, run `rake test` to run the tests.
You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
Please don't bump the version number in PRs; I'll handle releases.


## License

Recheck is an open core product.
See [LICENSE.md](https://github.com/recheckdev/recheck/blob/main/ruby/recheck/LICENSE.md) for terms of the freely available license.

The license for Recheck Pro can be found in [COMM-LICENSE.md](https://github.com/recheckdev/recheck/blob/main/ruby/recheck/COMM-LICENSE.md).
Purchase at [Recheck.dev](https://recheck.dev).
