# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../lib/ragent'

class TestDebug < Minitest::Test
  def setup
    @saved_debug = Ragent::Terminal.instance_variable_get(:@debug)
    @saved_color = Ragent::Terminal.instance_variable_get(:@color)
    Ragent::Terminal.color = false
  end

  def teardown
    Ragent::Terminal.debug = @saved_debug
    Ragent::Terminal.color = @saved_color
  end

  # --- Terminal.debug ---

  def test_debug_suppressed_when_off
    Ragent::Terminal.debug = false
    assert_equal('', capture_stderr { Ragent::Terminal.debug('should not appear') })
  end

  def test_debug_emits_when_on
    Ragent::Terminal.debug = true
    assert_includes capture_stderr { Ragent::Terminal.debug('hello') }, 'hello'
  end

  def test_debug_includes_debug_prefix
    Ragent::Terminal.debug = true
    assert_includes capture_stderr { Ragent::Terminal.debug('msg') }, '[debug]'
  end

  # --- API key redaction ---

  def test_openai_client_debug_does_not_leak_api_key
    Ragent::Terminal.debug = true
    secret = 'sk-test-secret-key-should-not-appear'
    client = Ragent::OpenAIClient.new(api_key: secret, tool_definitions: [])
    fake_resp = { 'choices' => [{ 'message' => { 'content' => 'hi', 'tool_calls' => nil } }] }
    client.define_singleton_method(:post) { |_path, _body| fake_resp }

    out = capture_stderr { client.call([{ role: 'user', content: 'hi' }]) }

    refute_includes out, secret
  end

  def test_openai_client_debug_includes_model_and_message_count
    Ragent::Terminal.debug = true
    client = Ragent::OpenAIClient.new(api_key: 'sk-x', tool_definitions: [], model: 'gpt-test')
    fake_resp = { 'choices' => [{ 'message' => { 'content' => 'hi', 'tool_calls' => nil } }] }
    client.define_singleton_method(:post) { |_path, _body| fake_resp }

    out = capture_stderr { client.call([{ role: 'user', content: 'hi' }]) }

    assert_includes out, 'gpt-test'
    assert_includes out, 'messages=1'
  end

  # --- tool call JSON ---

  def test_agent_loop_debug_includes_tool_name
    Ragent::Terminal.debug = true
    registry = Ragent::ToolRegistry.new
    registry.register('echo') { |args| args[:msg].to_s }

    responses = [
      Ragent::Response::ToolCall.new(tool: 'echo', args: { msg: 'hi' }),
      Ragent::Response::Final.new(content: 'done')
    ]
    client = Ragent::FakeModelClient.new(responses)
    loop = Ragent::AgentLoop.new(prompt: 'test', repo_root: Dir.tmpdir,
                                 model_client: client, tool_registry: registry)

    out = capture_stderr { loop.run }

    assert_includes out, '"tool":"echo"'
  end

  private

  def capture_stderr
    old = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = old
  end
end
