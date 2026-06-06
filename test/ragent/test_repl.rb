# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'
require 'fileutils'
require 'stringio'
require_relative '../../lib/ragent'

class TestRepl < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('ragent-repl-test')
    setup_git_repo
    @config = Ragent::Config.new(@dir)
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  # --- commands ---

  def test_tools_lists_all_tool_names
    run_repl('/tools', '/exit')
    Ragent::TOOL_DEFINITIONS.each do |t|
      assert_includes @out.string, t.name
    end
  end

  def test_status_shows_repo_root
    run_repl('/status', '/exit')
    assert_includes @out.string, @dir
  end

  def test_status_shows_approval_mode
    run_repl('/status', '/exit')
    assert_includes @out.string, 'ask'
  end

  def test_status_shows_history_turns
    run_repl('/status', '/exit')
    assert_includes @out.string, 'History turns:  0'
  end

  def test_help_lists_commands
    run_repl('/help', '/exit')
    assert_includes @out.string, '/tools'
    assert_includes @out.string, '/status'
    assert_includes @out.string, '/exit'
  end

  def test_unknown_command_shows_error
    run_repl('/unknown', '/exit')
    assert_includes @out.string, "Unknown command '/unknown'"
  end

  def test_exit_terminates_loop
    run_repl('/exit', 'this should not run')
    refute_includes @out.string, 'this should not run'
  end

  def test_quit_terminates_loop
    run_repl('/quit')
    assert_includes @out.string, 'Bye.'
  end

  def test_eof_terminates_loop
    run_repl
    assert_includes @out.string, 'Bye.'
  end

  def test_empty_lines_are_skipped
    call_count = 0
    client = make_client do
      call_count += 1
      Ragent::Response::Final.new(content: 'ok')
    end
    run_repl('', '   ', '/exit', client: client)
    assert_equal 0, call_count
  end

  def test_banner_is_printed_on_start
    run_repl('/exit')
    assert_includes @out.string, 'interactive'
  end

  # --- task execution ---

  def test_task_calls_model_and_prints_answer
    client = make_client { Ragent::Response::Final.new(content: 'hello from model') }
    run_repl('say hello', '/exit', client: client)
    assert_includes @out.string, 'hello from model'
  end

  def test_answer_section_header_is_printed
    client = make_client { Ragent::Response::Final.new(content: 'answer') }
    run_repl('do something', '/exit', client: client)
    assert_includes @out.string, '=== Answer ==='
  end

  # --- history ---

  def test_history_accumulates_between_turns
    received = []
    responses = [
      Ragent::Response::Final.new(content: 'first answer'),
      Ragent::Response::Final.new(content: 'second answer')
    ]
    client = Ragent::ModelClient.new
    client.define_singleton_method(:call) do |msgs|
      received << msgs.dup
      responses.shift
    end

    run_repl('first task', 'second task', '/exit', client: client)

    second_call = received[1]
    assert(second_call.any? { |m| m[:role] == 'user' && m[:content] == 'first task' },
           'second call should include first user turn')
    assert(second_call.any? { |m| m[:role] == 'assistant' && m[:content] == 'first answer' },
           'second call should include first assistant reply')
    assert(second_call.any? { |m| m[:role] == 'user' && m[:content] == 'second task' },
           'second call should include second user turn')
  end

  def test_status_history_turns_increments_after_task
    client = make_client { Ragent::Response::Final.new(content: 'ok') }
    run_repl('do a task', '/status', '/exit', client: client)
    assert_includes @out.string, 'History turns:  1'
  end

  def test_model_error_does_not_crash_repl
    client = Ragent::ModelClient.new
    client.define_singleton_method(:call) { |_| raise 'boom' }
    run_repl('bad task', '/exit', client: client)
    assert_includes @out.string, 'Error: boom'
    assert_includes @out.string, 'Bye.'
  end

  private

  def run_repl(*lines, client: nil)
    @out = StringIO.new
    input = StringIO.new("#{lines.join("\n")}\n")
    Ragent::Repl.new(
      workspace: @dir,
      auto_approve: true,
      allow_commands: false,
      config: @config,
      input: input,
      output: @out,
      model_client: client
    ).run
  end

  def make_client(&block)
    client = Ragent::ModelClient.new
    client.define_singleton_method(:call) { |_msgs| block.call }
    client
  end

  def setup_git_repo
    system('git', '-C', @dir, 'init', out: File::NULL, err: File::NULL)
    system('git', '-C', @dir, 'config', 'user.email', 'test@t.com', out: File::NULL, err: File::NULL)
    system('git', '-C', @dir, 'config', 'user.name', 'Test', out: File::NULL, err: File::NULL)
  end
end
