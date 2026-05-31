# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'json'
require_relative '../../lib/ragent'

class TestTranscript < Minitest::Test
  def setup
    @runs_dir = Dir.mktmpdir('ragent-transcript-test')
    @transcript = Ragent::Transcript.new(runs_dir: @runs_dir)
  end

  def teardown
    @transcript.close
    FileUtils.rm_rf(@runs_dir)
  end

  # --- run directory ---

  def test_creates_run_directory
    assert Dir.exist?(@transcript.run_dir)
  end

  def test_run_dir_is_under_runs_dir
    assert @transcript.run_dir.start_with?(@runs_dir)
  end

  def test_creates_transcript_file
    @transcript.close
    assert File.exist?(transcript_path)
  end

  # --- prompt ---

  def test_logs_prompt
    @transcript.log_prompt('hello world')
    entry = read_entries.first
    assert_equal 'prompt', entry['type']
    assert_equal 'hello world', entry['content']
  end

  # --- model responses ---

  def test_logs_tool_call_response
    response = Ragent::Response::ToolCall.new(tool: 'list_files', args: {})
    @transcript.log_model_response(response)
    entry = read_entries.first
    assert_equal 'tool_call', entry['type']
    assert_equal 'list_files', entry['tool']
    assert_equal({}, entry['args'])
  end

  def test_logs_tool_call_args
    response = Ragent::Response::ToolCall.new(tool: 'read_file', args: { path: 'README.md' })
    @transcript.log_model_response(response)
    assert_equal({ 'path' => 'README.md' }, read_entries.first['args'])
  end

  def test_logs_final_response
    response = Ragent::Response::Final.new(content: 'All done.')
    @transcript.log_model_response(response)
    entry = read_entries.first
    assert_equal 'final', entry['type']
    assert_equal 'All done.', entry['content']
  end

  # --- tool results ---

  def test_logs_tool_result
    @transcript.log_tool_result('list_files', "a.rb\nb.rb")
    entry = read_entries.first
    assert_equal 'tool_result', entry['type']
    assert_equal 'list_files', entry['tool']
    assert_equal "a.rb\nb.rb", entry['content']
    assert_equal false, entry['truncated']
  end

  def test_truncates_long_tool_results
    long_result = 'x' * 3000
    @transcript.log_tool_result('list_files', long_result)
    entry = read_entries.first
    assert_equal Ragent::Transcript::MAX_RESULT_LENGTH, entry['content'].length
    assert_equal true, entry['truncated']
  end

  def test_does_not_truncate_result_at_exact_limit
    result = 'x' * Ragent::Transcript::MAX_RESULT_LENGTH
    @transcript.log_tool_result('list_files', result)
    entry = read_entries.first
    assert_equal false, entry['truncated']
  end

  def test_custom_max_result_length
    transcript = Ragent::Transcript.new(runs_dir: @runs_dir, max_result_length: 10)
    transcript.log_tool_result('echo', 'x' * 20)
    entry = lines_from(transcript).map { |l| JSON.parse(l) }.first
    assert_equal 10, entry['content'].length
    assert_equal true, entry['truncated']
  ensure
    transcript.close
  end

  # --- JSONL format ---

  def test_each_line_is_valid_json
    @transcript.log_prompt('hello')
    @transcript.log_model_response(Ragent::Response::ToolCall.new(tool: 'list_files', args: {}))
    @transcript.log_tool_result('list_files', 'a.rb')
    @transcript.log_model_response(Ragent::Response::Final.new(content: 'done'))

    lines_from(@transcript).each do |line|
      assert JSON.parse(line)
    end
  end

  def test_entries_are_written_in_order
    @transcript.log_prompt('hello')
    @transcript.log_model_response(Ragent::Response::ToolCall.new(tool: 'list_files', args: {}))
    @transcript.log_tool_result('list_files', 'a.rb')
    @transcript.log_model_response(Ragent::Response::Final.new(content: 'done'))

    types = read_entries.map { |e| e['type'] }
    assert_equal %w[prompt tool_call tool_result final], types
  end

  # --- integration with AgentLoop ---

  def test_agent_loop_writes_full_transcript
    registry = Ragent::ToolRegistry.new
    registry.register('echo') { |args| args[:message].to_s }

    client = Ragent::FakeModelClient.new([
                                           Ragent::Response::ToolCall.new(tool: 'echo', args: { message: 'hi' }),
                                           Ragent::Response::Final.new(content: 'done')
                                         ])

    Ragent::AgentLoop.new(
      prompt: 'test',
      repo_root: @runs_dir,
      model_client: client,
      tool_registry: registry,
      transcript: @transcript
    ).run

    types = read_entries.map { |e| e['type'] }
    assert_equal %w[prompt tool_call tool_result final], types
  end

  private

  def transcript_path
    File.join(@transcript.run_dir, 'transcript.jsonl')
  end

  def lines_from(transcript)
    transcript.close
    File.readlines(File.join(transcript.run_dir, 'transcript.jsonl')).map(&:chomp)
  end

  def read_entries
    lines_from(@transcript).map { |l| JSON.parse(l) }
  end
end
