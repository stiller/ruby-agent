# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../../lib/ragent'

class TestSystemPrompt < Minitest::Test
  TOOLS = %w[list_files read_file search_text].freeze
  REPO  = '/workspace'

  def setup
    @prompt = Ragent::Prompts::SystemPrompt.new(repo_root: REPO, tools: TOOLS).to_s
  end

  # --- repo root ---

  def test_includes_repo_root
    assert_includes @prompt, REPO
  end

  def test_repo_root_is_present_once_at_minimum
    assert @prompt.include?(REPO)
  end

  # --- tool names ---

  def test_includes_list_files_tool
    assert_includes @prompt, 'list_files'
  end

  def test_includes_read_file_tool
    assert_includes @prompt, 'read_file'
  end

  def test_includes_search_text_tool
    assert_includes @prompt, 'search_text'
  end

  def test_includes_all_tool_names
    TOOLS.each { |t| assert_includes @prompt, t }
  end

  # --- required instructions ---

  def test_instructs_not_to_guess_file_contents
    assert_match(/guess|assume/i, @prompt)
  end

  def test_instructs_to_use_tools
    assert_match(/tool/i, @prompt)
  end

  def test_instructs_to_summarize
    assert_match(/summary|summarize|summarise/i, @prompt)
  end

  def test_instructs_small_steps
    assert_match(/step/i, @prompt)
  end

  # --- dynamic content ---

  def test_uses_provided_repo_root
    custom = Ragent::Prompts::SystemPrompt.new(repo_root: '/my/custom/repo', tools: TOOLS).to_s
    assert_includes custom, '/my/custom/repo'
    refute_includes custom, '/workspace'
  end

  def test_uses_provided_tool_names
    custom = Ragent::Prompts::SystemPrompt.new(repo_root: REPO, tools: %w[my_tool]).to_s
    assert_includes custom, 'my_tool'
    refute_includes custom, 'list_files'
  end

  # --- repo-level instructions ---

  def test_instructions_are_included_when_provided
    prompt = Ragent::Prompts::SystemPrompt.new(repo_root: REPO, tools: TOOLS,
                                               instructions: 'always write tests').to_s
    assert_includes prompt, 'always write tests'
  end

  def test_instructions_section_header_is_present
    prompt = Ragent::Prompts::SystemPrompt.new(repo_root: REPO, tools: TOOLS,
                                               instructions: 'do something').to_s
    assert_includes prompt, 'Repo-level instructions'
  end

  def test_nil_instructions_produces_no_instructions_section
    prompt = Ragent::Prompts::SystemPrompt.new(repo_root: REPO, tools: TOOLS,
                                               instructions: nil).to_s
    refute_includes prompt, 'Repo-level instructions'
  end

  def test_blank_instructions_produces_no_instructions_section
    prompt = Ragent::Prompts::SystemPrompt.new(repo_root: REPO, tools: TOOLS,
                                               instructions: "   \n  ").to_s
    refute_includes prompt, 'Repo-level instructions'
  end

  # --- integration: AgentLoop sends system prompt as first message ---

  def test_agent_loop_sends_system_message_first
    roles = []
    client = spy_client(roles)
    prompt_obj = Ragent::Prompts::SystemPrompt.new(repo_root: REPO, tools: TOOLS)
    Dir.mktmpdir do |dir|
      Ragent::AgentLoop.new(
        prompt: 'test', repo_root: dir,
        model_client: client, tool_registry: Ragent::ToolRegistry.new,
        system_prompt: prompt_obj
      ).run
    end
    assert_equal 'system', roles.first
    assert_equal 'user', roles[1]
  end

  private

  def spy_client(roles)
    client = Ragent::FakeModelClient.new([Ragent::Response::Final.new(content: 'done')])
    client.define_singleton_method(:call) do |messages|
      roles.concat(messages.map { |m| m[:role] })
      super(messages)
    end
    client
  end
end
