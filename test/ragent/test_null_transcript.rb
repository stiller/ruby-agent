# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../lib/ragent'

class TestNullTranscript < Minitest::Test
  def setup
    @transcript = Ragent::NullTranscript.new
  end

  def test_run_dir_is_nil
    assert_nil @transcript.run_dir
  end

  def test_not_persistent
    refute @transcript.persistent?
  end

  def test_log_prompt_is_a_no_op
    assert_nil @transcript.log_prompt('hello')
  end

  def test_log_model_response_is_a_no_op
    response = Ragent::Response::Final.new(content: 'done')
    assert_nil @transcript.log_model_response(response)
  end

  def test_log_tool_result_is_a_no_op
    assert_nil @transcript.log_tool_result('list_files', 'a.rb')
  end

  def test_close_is_safe
    assert_nil @transcript.close
  end
end
