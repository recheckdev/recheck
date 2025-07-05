# frozen_string_literal: true

class TestCli < Test
  def setup
    @original_argv = ARGV.dup
    ARGV.clear
  end

  def teardown
    ARGV.replace(@original_argv)
  end

  def run_cli cli
  end

  def test_option_parsing
    cli = Recheck::Cli.new(argv: ["--help"])
    assert_equal ["--help"], cli.instance_variable_get(:@argv)
  end

  # This class is pretty untestable right now, but it's a small wrapper on Optimist.
  # I'm deciding if I should fork Optimist and refactor away the exit() calls.
end
