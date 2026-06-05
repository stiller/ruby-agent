# frozen_string_literal: true

require_relative '../test_helper'
require 'json'
require_relative '../../lib/ragent'

class TestOpenAIClient < Minitest::Test
  FAKE_KEY = 'sk-test-fake'

  def setup
    @definitions = [
      Ragent::ToolDefinition.new(
        name: 'list_files',
        description: 'List files',
        parameters: { type: 'object', properties: {}, required: [] }
      )
    ]
  end

  # --- constructor ---

  def test_raises_without_api_key
    assert_raises(ArgumentError) { Ragent::OpenAIClient.new(api_key: nil) }
  end

  def test_raises_with_empty_api_key
    assert_raises(ArgumentError) { Ragent::OpenAIClient.new(api_key: '') }
  end

  # --- response parsing ---

  def test_returns_final_response
    result = client(final_api_response('Done.')).call([user('hi')])
    assert_equal 'final', result.type
    assert_equal 'Done.', result.content
  end

  def test_returns_tool_call_response
    result = client(tool_call_api_response('list_files', {}, 'call_123')).call([user('hi')])
    assert_equal 'tool_call', result.type
    assert_equal 'list_files', result.tool
    assert_equal 'call_123', result.id
  end

  def test_parses_tool_call_args
    result = client(tool_call_api_response('read_file', { 'path' => 'README.md' }, 'call_abc')).call([user('hi')])
    assert_equal({ 'path' => 'README.md' }, result.args)
  end

  def test_treats_empty_tool_calls_array_as_final
    response = { 'choices' => [{ 'message' => { 'role' => 'assistant', 'content' => 'ok', 'tool_calls' => [] } }] }
    result = client(response).call([user('hi')])
    assert_equal 'final', result.type
  end

  def test_raises_api_error_on_http_failure
    c = error_client('401', '{"error":"Unauthorized"}')
    assert_raises(Ragent::APIError) { c.call([user('hi')]) }
  end

  def test_api_error_includes_status_code
    c = error_client('500', 'Internal Server Error')
    err = assert_raises(Ragent::APIError) { c.call([user('hi')]) }
    assert_match '500', err.message
  end

  def test_raises_on_malformed_response
    c = client({ 'choices' => [] })
    assert_raises(Ragent::APIError) { c.call([user('hi')]) }
  end

  # --- request building ---

  def test_sends_tool_schemas
    body = capture_body { |c| c.call([user('hi')]) }
    assert_equal 1, body[:tools].length
    assert_equal 'function', body[:tools].first[:type]
    assert_equal 'list_files', body[:tools].dig(0, :function, :name)
  end

  def test_omits_tools_key_when_no_definitions
    body = capture_body(tool_definitions: []) { |c| c.call([user('hi')]) }
    refute body.key?(:tools)
  end

  def test_serializes_user_message
    body = capture_body { |c| c.call([user('hello')]) }
    msg = body[:messages].first
    assert_equal 'user', msg[:role]
    assert_equal 'hello', msg[:content]
  end

  def test_serializes_assistant_tool_call_message
    msgs = [
      user('hi'),
      { role: 'assistant', tool_calls: [{ id: 'call_1', name: 'list_files', args: {} }] }
    ]
    body = capture_body { |c| c.call(msgs) }
    assistant = body[:messages][1]
    assert_equal 'assistant', assistant[:role]
    assert_nil assistant[:content]
    assert_equal 'call_1', assistant.dig(:tool_calls, 0, :id)
    assert_equal 'list_files', assistant.dig(:tool_calls, 0, :function, :name)
  end

  def test_serializes_tool_result_message
    msgs = [
      user('hi'),
      { role: 'assistant', tool_calls: [{ id: 'call_1', name: 'list_files', args: {} }] },
      { role: 'tool', tool_call_id: 'call_1', content: 'a.rb' }
    ]
    body = capture_body { |c| c.call(msgs) }
    tool_msg = body[:messages][2]
    assert_equal 'tool', tool_msg[:role]
    assert_equal 'call_1', tool_msg[:tool_call_id]
    assert_equal 'a.rb', tool_msg[:content]
  end

  def test_sends_model_name
    body = capture_body { |c| c.call([user('hi')]) }
    assert_equal 'test-model', body[:model]
  end

  private

  def client(canned_response)
    stub_client(canned_response)
  end

  def stub_client(canned_response, tool_definitions: @definitions)
    c = Ragent::OpenAIClient.new(
      tool_definitions: tool_definitions,
      api_key: FAKE_KEY,
      base_url: 'https://example.com',
      model: 'test-model'
    )
    c.define_singleton_method(:post) { |_path, _body| canned_response }
    c
  end

  def error_client(code, body)
    c = Ragent::OpenAIClient.new(api_key: FAKE_KEY, base_url: 'https://example.com')
    c.define_singleton_method(:post) { |_path, _body| raise Ragent::APIError, "HTTP #{code}: #{body}" }
    c
  end

  def capture_body(tool_definitions: @definitions)
    captured = nil
    canned = final_api_response('ok')
    c = Ragent::OpenAIClient.new(
      tool_definitions: tool_definitions,
      api_key: FAKE_KEY,
      base_url: 'https://example.com',
      model: 'test-model'
    )
    c.define_singleton_method(:post) do |_path, body|
      captured = body
      canned
    end
    yield c
    captured
  end

  def user(content)
    { role: 'user', content: content }
  end

  def final_api_response(content)
    { 'choices' => [{ 'message' => { 'role' => 'assistant', 'content' => content, 'tool_calls' => nil } }] }
  end

  def tool_call_api_response(name, args, id)
    { 'choices' => [{
      'message' => {
        'role' => 'assistant', 'content' => nil,
        'tool_calls' => [{
          'id' => id, 'type' => 'function',
          'function' => { 'name' => name, 'arguments' => JSON.generate(args) }
        }]
      }
    }] }
  end
end
