Beta note:
Recheck is in __early beta__.
You should expect and report crashes, bugs, or missing features.
It is safe to try out because, by design, it does not write to your database.

Please don't submit Recheck to Lobsters/Reddit/Hacker News/etc. yet,
I'd really like it to exercise it and reach 1.0 first.

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
See [license.md](https://github.com/recheckdev/recheck/blob/main/ruby/recheck/license.md) for terms of the freely available license.

The license for Recheck Pro can be found in [comm-license.md](https://github.com/recheckdev/recheck/blob/main/ruby/recheck/comm-license.md).
Purchase at [Recheck.dev](https://recheck.dev).
