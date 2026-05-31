# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/ragent'

class TestFakeModelClient < Minitest::Test
  # --- tool call responses ---

  def test_returns_tool_call_type
    response = client_with(tool_call('list_files', {})).call([])
    assert_equal 'tool_call', response.type
  end

  def test_returns_tool_name
    response = client_with(tool_call('list_files', {})).call([])
    assert_equal 'list_files', response.tool
  end

  def test_returns_tool_args
    response = client_with(tool_call('read_file', { path: 'README.md' })).call([])
    assert_equal({ path: 'README.md' }, response.args)
  end

  def test_returns_empty_args
    response = client_with(tool_call('list_files', {})).call([])
    assert_equal({}, response.args)
  end

  # --- final responses ---

  def test_returns_final_type
    response = client_with(final('Done.')).call([])
    assert_equal 'final', response.type
  end

  def test_returns_final_content
    response = client_with(final('This repo appears to be a Ruby project.')).call([])
    assert_equal 'This repo appears to be a Ruby project.', response.content
  end

  # --- sequencing ---

  def test_returns_responses_in_order
    client = Ragent::FakeModelClient.new([
                                           tool_call('list_files', {}),
                                           final('Done.')
                                         ])
    assert_equal 'tool_call', client.call([]).type
    assert_equal 'final', client.call([]).type
  end

  def test_each_call_consumes_one_response
    client = Ragent::FakeModelClient.new([final('a'), final('b'), final('c')])
    assert_equal 'a', client.call([]).content
    assert_equal 'b', client.call([]).content
    assert_equal 'c', client.call([]).content
  end

  def test_raises_when_responses_exhausted
    client = Ragent::FakeModelClient.new([])
    assert_raises(RuntimeError) { client.call([]) }
  end

  # --- base interface ---

  def test_base_client_raises_not_implemented
    assert_raises(NotImplementedError) { Ragent::ModelClient.new.call([]) }
  end

  private

  def tool_call(tool, args)
    Ragent::Response::ToolCall.new(tool: tool, args: args)
  end

  def final(content)
    Ragent::Response::Final.new(content: content)
  end

  def client_with(response)
    Ragent::FakeModelClient.new([response])
  end
end
