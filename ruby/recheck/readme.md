Beta note:
Recheck is in __early beta__.
You should expect and report crashes, bugs, or missing features.
It is safe to try out because, by design, it does not write to your database.

Please don't submit Recheck to Lobsters/Reddit/Hacker News/etc. yet,
I'd really like it to exercise it and reach 1.0 first.

# Recheck

Recheck is a tool for checking the correctness of production data, inspired by an internal tool at Stripe.

Have you ever pulled a record out of your database and been surprised to find it's not valid?

    Order.find(123).valid?
    => false

Huh!?

You've probably seen this sort of problem, where production data is inconsistent or "impossible".
Not every row, but one in a few hundred thousand or a few million.
When you have a background job, hit a third-party API, or have a state machine that measures transition in days,
you sometimes get these bad records where there's a few `NULL`s where there shouldn't be,
a couple fields on a record contradict each other, or associated records are missing.

**It's not your codebase. This happens in every database at scale.**

In theory no background job would crash at 3 AM halfway through its run and every business rule would have perfectly reliable SQL constraints.
But the cost of perfection is very high, perhaps infinitely high.

**Recheck is the missing tool for pragmatically addressing data integrity.**

When you see a user report or an exception, you have to query to see if there's more bad data.
With Recheck you wrap up that query in a "check", a small bit of code like a unit test for your production data.
Out of the box it can detect and use your model validations, but the real value is in writing your own checks as you implement code or investigate bugs.
You can manually run your checks, or stand up a Recheck service to run them continuously in the background.

It's worth writing a check any time you have:

- A background job that edits or adds records
- A null is replaced by a third-party API call
- A painful bug you don't want to see again
- A slow state machine
- Any technical or business rule logic that is difficult to write a db constraint for

(Not using Ruby? Sign up to [get notified](https://recheck.dev) when Recheck is available in more languages.)


## Install and Configure

Add Recheck to your `Gemfile`:

    gem "recheck"
    # if you're using rails, instead add:
    gem "recheck-rails"

Recheck runs against production data, so don't put it only in a `development` or `test` group like a testing tool.

Generate basic checks based on your existing models with:

    $ bundle exec recheck setup
    creating recheck/
    generating recheck/recheck_helper.rb
    creating recheck/site/domain_checker.rb
    creating recheck/site/tls_checker.rb
    detected ActiveRecord models, creating recheck/model/
      app/models/comment.rb -> recheck/model/comment_checker.rb
      app/models/story.rb -> recheck/model/story_checker.rb
      app/models/user.rb -> recheck/model/user_checker.rb
    detected ActiveJob jobs, creating recheck/job/
      app/jobs/user_cleanup_job.rb -> recheck/job/user_cleanup_checker.rb
    detected Sidekiq workers, creating recheck/worker/
      app/workers/refresh.rb -> recheck/worker/refresh_checker.rb

Run `git add --all` and `git commit` to record this baseline.

**You should immediately run these default checks to start finding bad data.**


## Run Your Checks

Keep in mind: This runs against _production_ and will usually run full table scans.
If you have a huge amount of data this could be a lot of I/O.
If you're large enough to have an OLAP/data warehouse, consult with your data team about running against that instead of your OLTP.

Run your checks:

    $ bundle exec recheck
    CommentChecker ... 2,442 pass 0 fail
    StoryChecker .. 1,196 pass 0 fail
    UserChecker ..x. 3,501 pass 3 fail
    Completed in 28 seconds

Each `.` is a set of 1,000 records passing, each `x` is a set with at least one failure.
The exit code is `0` when all checks pass,
`1` when any checks fail, or
`2` when any checks error out (takes precedence).

A failure looks like:

    $ bundle exec recheck recheck/model/user_checker.rb
    UserChecker ...x. 3,501 pass, 3 fail

    Failures:
    UserLoginChecker#check_users_are_synced_to_ldap recheck/model/user_checker.rb:46
      2342
    UserLoginChecker#Bug1422 recheck/model/user_checker.rb:105
      1755
      2342

By default `recheck` only prints to the command line, but you can write `Reporter`s to notify teams by email/slack/issue tracker in regular use.

You can run subsets of checks by filename or line number:

    $ recheck recheck/job
    $ recheck recheck/job/user* recheck/doc_store/integration_checker.rb
    $ recheck recheck/model/user_checker.rb
    $ recheck recheck/model/user_checker.rb:46

When you have a lot of data and checks take more than a few minutes to run, Recheck will recommend changing strategies,
for example to check all recent records but sample randomly from older data that's less likely to have new errors.
The schedulers and strategies appropriate for millions of records and gigabytes of data are available in [Recheck Pro](https://recheck.dev/pro), along with a nice web interface.


## Write Checks

A `Checker` is a class that groups queries and related checks, a `check` is an individual method that checks a single record.
Group your checks by query, team, or purpose.
The runner only looks for methods named `query` and `check_`, so you can use delegation, modules, and inheritance (as long as inheritance eventually reaches `Recheck::Checker::Base`) as you like to organize your checks.


Here's a short example:

```ruby
class UserContactChecker < Recheck::Checker::Base
  # Query for records to check:
  def query
    # Watching for Bug #556, which left some users without shipping/contact info
    # if the user edited their profile while the daily sync job was running.
    User.where(email: nil)
      .left_outer_joins(:mailing_addresses, :phone_numbers)
      .where(mailing_addresses: { id: nil })
      .where(phone_numbers: { id: nil })
      .distinct
  end

  # The simplest possible check would be to consider every queried record bad.
  # This is standard when you're checking for a particular, well-defined bug.
  def check_bad_data_exists(_)= false
end
```

Here's a longer example, showing the 4 hooks available:

```ruby
# recheck/models/user_logins_checker.rb
# Checkers must inherit from Recheck::Checker::Base to be registered to run.
class UserLoginsChecker < Recheck::Checker::Base

  # Hook 1: initialize (optional)
  # Runs once to prepare a shared resource for the checks to use:
  def intitialize
    @ldap = Net::LDAP.new({ host: "example.com", port: 389, auth: LDAP_CREDENTIALS })
  end

  # Hook 2: query* (required)
  # Your query might be very simple, like checking all records.
  # You can have multiple query methods; all records are run against all checks.
  # You can return any Enumerable.
  def query_all
    User.all.include(:avatar).find_each
  end

  # Hook 3: check* (optional)
  # Each check inspects a single record, the name must start with "check".
  #
  # While it would be nice to always be able to query out bad data,
  # sometimes it's easier to express "bad" in code, or you have to
  # integrate with other data sources.
  #
  # A check is a function that receives a single record and returns
  # false or nil for a failing record; anything else is a pass.
  def check_users_are_synced_to_ldap(user)
    # ldap syncs every minute so pass very recently changed users:
    return true if user.updated_at >= 1.minute.ago

    count = @ldap.search({
      base: "dc=example, dc=com",
      filter: Net::LDAP::Filter.eq("mail", User.email),
      return_result: false
    }).size

    # user appears in ldap exactly once, right?
    return count == 1
  end

  # You can define many checks for your records:
  def check_user_has_avatar_on_s3(user)
    # ...
  end

  # That's all you need to implement a checker, but you can have any other
  # methods or attributes you want. This is mostly useful for metadata for
  # Reporters, so remember this method for the next section.
  def team= :security
end

Some tips for writing checks:

  * Checkers are cheap. Don't be shy about splitting up your checkers by team or function.
    Recheck looks for any file `recheck/**/*_checker.rb` or you can give any path on the command line.
  * Generally you want checks to avoid side effects because you can't control their scheduling,
    but if you can automatically fix up your data, go for it.
    Recheck is a pragmatic tool for keeping your data healthy.
  * It's great to include detailed comments with links in your checkers so that when they alert
    to give a running start on context for the people dealing with the alert.
    Maybe a [runbook](https://www.pagerduty.com/resources/learn/what-is-a-runbook/)?


## Reporters

Reporters are how you turn failing checks into emails, bug tracker tickets, or any other useful notification or report.
You can notify different teams however they most "enjoy" hearing about bad data.

When you run your check suite you can name reporters to use:

    recheck run --reporter Json recheck/validation/user.rb | jq -R -r "fromjson?"
    {
      "UserValidationChecker": {
        "check_no_invalid_records_found": {
          "counts": {
            "counts": {
              "pass": 0,
              "fail": 0,
              "exception": 0,
              "blanket": 0,
              "no_query_methods": 0,
              "no_queries": 0,
              "no_check_methods": 0,
              "no_checks": 0
            },
            "queries": 0
          },
          "fail": [],
          "exception": []
        }
      }
    }

Notice this doesn't show the usual terminal output?
That's printed by `Recheck::Reporter::Default`, which recheck only includes if you don't name any reporters in your command.

When you `recheck run`, you can give the full namespace to a class like `--reporter Recheck::Reporter::Json` but it searches in `Recheck::Reporter` for the convenience of saying `--reporter Json`.

Reporters are even easier to write than checker classes:

```ruby
# recheck/reporter/email_team_reporter.rb
# Checkers must inherit from Recheck::Reporter::Base to be registered as available.
class EmailTeamReporter < Recheck::Reporter::Base
  # Optional: appears in `recheck reporters`.
  def self.help
  end

  # Required: receives the arg from the command line.
  # raise ArgumentError for any problem with arg
  def initialize(arg:)
    @team_lookup = TeamLookupService.new(api_key: arg)
  rescue InvalidApiKey
    raise ArgumentError, "API key not accepted for team lookup"
  end

  # There are four hooks, all optional:
  # around_run: fires around the entire run
  # around_query: fires around each query
  # around_checker: fires around each checker
  # around_check: fires for each call to a check_ of each record

  # Important warning: all your hooks _must_ yield to run the next part of the suite.

  def around_run(checkers:)
    total_counts = yield

    Email.new({
      to: @team_lookup.find(:ops),
      subject: "check run completed",
      body: "results: #{total_counts.inspect}"
    }).send_now!
  end

  # This Reporter doesn't need a around_checker or around_query,
  # so it doesn't define them.

  def around_check(checker:, query:, check:)
    result = yield

    if result.is_a? Recheck::Error
      Email.new({
        # Remember defining .team in the checker example above?
        to: @team_lookup.find(checker.team),
        subject: "failing check",
        body: result.inspect
      }).send_now!
    end
  end
end
```

To pass the API key as the reporter's arg:

    bundle exec recheck --reporter EmailTeamReporter:api_key_123abc

A reporter takes a single string `arg` after a `:`, which is deliberately simple to avoid the creeping horror of shell parsing.

If you need to pass complex options or run from a job, you can script it:

```ruby
require "recheck"

# load reporters and checkers from this project and elsewhere
Dir.glob([
  "recheck/check/**/*.rb",
  "/path/to/shared/checks/**/*.rb",
  "recheck/reporter/**/*.rb"
]).each do |file|
  require_relative file
end

# you can instantiate your checkers and reporters with additional config
Recheck::Runner.new(
  checkers: [
    UserChecker.new(role: :admin),
    UserChecker.new(role: :customer_suport),
    SecurityChecker.new
  ],
  reporters: [
    SlackReporter.new(channels: [:security, :ops].merge(ARGV.map(&:to_sym))
  ]
)
```

Run `recheck reporters` to list your loaded reporters.

Read [the reporters that ship with Recheck](lib/recheck/reporters.rb) for more ideas.


## Production

When you have your check suite and reporters, it's time to run them in production.

You could run `bundle exec recheck recheck/job/* recheck/model/user_checker.rb --reporter ... --reporter ...` and so on manually,
but Recheck's real value comes when you schedule it to run automatically.
Start with running all your checks daily and then specialize into running subsets more or less frequently as you gain confidence and build out a big suite.


Recheck is free for personal and commercial use,
but pretty much all non-trivial commercial systems would benefit by upgrading to [Recheck Pro](https://recheck.dev/pro).
It comes with an admin panel to track issues over time, silence flaky or low-priority checks, and more:

[admin screenshot TK]

The admin panel also handles running your checks continuously in the background.

Recheck Pro also includes sophisticated strategies to catch issues ASAP while minimizing database load.
For example, if you add the line `schedule Recheck::Pro::RecentlyUpdated`, it will:

- every minute, run checks against records edited in the last hour
- every hour, run checks against records edited in the last day
- every day, run checks against records edited in the last 30 days
- every day, run checks against 1% of records edited more than 30 days ago,
  but back off and warn if the database is responding slowly

See the [full docs](https://recheck.dev/doc) for more.


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
