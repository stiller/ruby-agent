# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../../../lib/ragent'

class TestRunCommand < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('ragent-run-command-test')
    @tool = Ragent::Tools::RunCommand.new(@dir)
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_captures_stdout
    result = @tool.call('echo hello')
    assert_includes result.stdout, 'hello'
  end

  def test_captures_stderr
    result = @tool.call('echo error >&2')
    assert_includes result.stderr, 'error'
  end

  def test_zero_exit_status_on_success
    result = @tool.call('true')
    assert_equal 0, result.exit_status
  end

  def test_nonzero_exit_status_on_failure
    result = @tool.call('false')
    refute_equal 0, result.exit_status
  end

  def test_result_to_s_includes_exit_status
    result = @tool.call('true')
    assert_includes result.to_s, 'Exit status: 0'
  end

  def test_runs_in_workspace_directory
    File.write(File.join(@dir, 'marker.txt'), 'hello')
    result = @tool.call('ls')
    assert_includes result.stdout, 'marker.txt'
  end

  def test_truncates_long_stdout
    tool = Ragent::Tools::RunCommand.new(@dir)
    result = tool.call("ruby -e 'print \"x\" * #{Ragent::Tools::RunCommand::MAX_OUTPUT + 100}'")
    assert_includes result.stdout, '[output truncated]'
    assert result.stdout.bytesize <= Ragent::Tools::RunCommand::MAX_OUTPUT + 30
  end

  def test_returns_error_on_timeout
    tool = Ragent::Tools::RunCommand.new(@dir, timeout: 1)
    result = tool.call('sleep 100')
    assert_instance_of Ragent::Tools::RunCommand::Error, result
    assert_match(/timed out/i, result.to_s)
  end

  def test_returns_error_on_missing_command
    result = @tool.call('nonexistent_command_xyz_ragent')
    assert_instance_of Ragent::Tools::RunCommand::Error, result
  end
end
