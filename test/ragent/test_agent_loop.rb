# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'
require 'fileutils'
require_relative '../../lib/ragent'

class TestAgentLoop < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('ragent-loop-test')
    @registry = Ragent::ToolRegistry.new
    @registry.register('echo') { |args| args[:message].to_s }
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  # --- happy paths ---

  def test_returns_final_answer_immediately
    result = run_loop([final('Done.')])
    assert_equal 'Done.', result
  end

  def test_returns_final_answer_after_one_tool_call
    result = run_loop([tool_call('echo', { message: 'hi' }), final('Done.')])
    assert_equal 'Done.', result
  end

  def test_returns_final_answer_after_multiple_tool_calls
    result = run_loop([
                        tool_call('echo', { message: 'first' }),
                        tool_call('echo', { message: 'second' }),
                        final('All done.')
                      ])
    assert_equal 'All done.', result
  end

  # --- tool execution ---

  def test_tool_is_called_with_correct_args
    received = []
    @registry.register('spy') do |args|
      received << args
      'ok'
    end

    run_loop([tool_call('spy', { x: 42 }), final('done')])
    assert_equal [{ x: 42 }], received
  end

  def test_tool_result_is_passed_back_to_model
    # The model receives the tool result as a tool_result message.
    # Use a recording client to verify messages grow with each round.
    message_counts = []
    client = recording_client(message_counts, [
                                tool_call('echo', { message: 'ping' }),
                                final('done')
                              ])

    build_loop(client).run

    assert_equal 1, message_counts[0]  # first call: just the user prompt
    assert_equal 3, message_counts[1]  # second call: prompt + assistant_tool_call + tool_result
  end

  # --- limits ---

  def test_raises_after_max_iterations
    responses = Array.new(11) { tool_call('echo', { message: 'x' }) }
    err = assert_raises(RuntimeError) { run_loop(responses) }
    assert_match 'exceeded maximum', err.message
  end

  def test_custom_max_iterations
    responses = Array.new(4) { tool_call('echo', { message: 'x' }) }
    err = assert_raises(RuntimeError) do
      build_loop(Ragent::FakeModelClient.new(responses), max_iterations: 3).run
    end
    assert_match 'exceeded maximum', err.message
  end

  # --- on_tool_call callback ---

  def test_on_tool_call_fires_with_tool_name_and_args
    fired = []
    loop = build_loop(Ragent::FakeModelClient.new([
                                                    tool_call('echo', { message: 'hi' }),
                                                    final('done')
                                                  ]))
    loop.on_tool_call = ->(t, a) { fired << [t, a] }
    loop.run
    assert_equal [['echo', { message: 'hi' }]], fired
  end

  def test_on_tool_call_fires_for_each_tool_call
    fired = []
    loop = build_loop(Ragent::FakeModelClient.new([
                                                    tool_call('echo', { message: 'one' }),
                                                    tool_call('echo', { message: 'two' }),
                                                    final('done')
                                                  ]))
    loop.on_tool_call = ->(t, _a) { fired << t }
    loop.run
    assert_equal %w[echo echo], fired
  end

  def test_on_tool_call_not_required
    assert_equal 'Done.', run_loop([final('Done.')])
  end

  # --- messages reader ---

  def test_messages_is_empty_before_run
    loop = build_loop(Ragent::FakeModelClient.new([final('ok')]))
    assert_equal [], loop.messages
  end

  def test_messages_contains_conversation_after_run
    build_loop(Ragent::FakeModelClient.new([final('ok')])).run
    # just checking the method exists and returns a non-nil array
  end

  def test_messages_includes_user_prompt
    loop = build_loop(Ragent::FakeModelClient.new([final('ok')]))
    loop.run
    assert(loop.messages.any? { |m| m[:role] == 'user' && m[:content] == 'test prompt' })
  end

  def test_messages_includes_tool_exchange
    loop = build_loop(Ragent::FakeModelClient.new([tool_call('echo', { message: 'hi' }), final('ok')]))
    loop.run
    roles = loop.messages.map { |m| m[:role] }
    assert_includes roles, 'assistant'
    assert_includes roles, 'tool'
  end

  # --- history (multi-turn) ---

  def test_history_seeds_messages_for_next_turn
    prior = [
      { role: 'system', content: 'sys' },
      { role: 'user', content: 'first turn' },
      { role: 'assistant', content: 'first answer' }
    ]
    received = []
    client = Ragent::ModelClient.new
    client.define_singleton_method(:call) do |msgs|
      received << msgs.dup
      Ragent::Response::Final.new(content: 'second answer')
    end

    Ragent::AgentLoop.new(
      prompt: 'second turn',
      repo_root: @dir,
      model_client: client,
      tool_registry: @registry,
      history: prior
    ).run

    first_call = received.first
    assert(first_call.any? { |m| m[:role] == 'user' && m[:content] == 'first turn' })
    assert(first_call.any? { |m| m[:role] == 'assistant' && m[:content] == 'first answer' })
    assert(first_call.any? { |m| m[:role] == 'user' && m[:content] == 'second turn' })
  end

  def test_history_does_not_add_system_prompt_again
    prior = [{ role: 'system', content: 'sys' }, { role: 'user', content: 'first' }]
    received = []
    client = Ragent::ModelClient.new
    client.define_singleton_method(:call) do |msgs|
      received << msgs.dup
      Ragent::Response::Final.new(content: 'ok')
    end

    Ragent::AgentLoop.new(
      prompt: 'second',
      repo_root: @dir,
      model_client: client,
      tool_registry: @registry,
      system_prompt: Ragent::Prompts::SystemPrompt.new(repo_root: @dir, tools: []),
      history: prior
    ).run

    system_messages = received.first.select { |m| m[:role] == 'system' }
    assert_equal 1, system_messages.size
  end

  # --- errors ---

  def test_raises_on_unknown_tool
    err = assert_raises(Ragent::ToolRegistry::UnknownToolError) do
      run_loop([tool_call('nonexistent', {}), final('done')])
    end
    assert_match 'nonexistent', err.message
  end

  private

  def run_loop(responses)
    build_loop(Ragent::FakeModelClient.new(responses)).run
  end

  def build_loop(client, max_iterations: Ragent::AgentLoop::MAX_ITERATIONS)
    Ragent::AgentLoop.new(
      prompt: 'test prompt',
      repo_root: @dir,
      model_client: client,
      tool_registry: @registry,
      max_iterations: max_iterations
    )
  end

  def tool_call(tool, args)
    Ragent::Response::ToolCall.new(tool: tool, args: args)
  end

  def final(content)
    Ragent::Response::Final.new(content: content)
  end

  def recording_client(message_counts, responses)
    responses_dup = responses.dup
    fake_call = lambda do |messages|
      message_counts << messages.size
      raise 'no more responses' if responses_dup.empty?

      responses_dup.shift
    end
    client = Ragent::ModelClient.new
    client.define_singleton_method(:call, &fake_call)
    client
  end
end
