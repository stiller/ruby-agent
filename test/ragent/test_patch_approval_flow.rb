# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'
require 'fileutils'
require 'stringio'
require_relative '../../lib/ragent'

class TestPatchApprovalFlow < Minitest::Test
  DIFF = "--- a/lib/foo.rb\n+++ b/lib/foo.rb\n@@ -1 +1 @@\n-old\n+new\n"

  def setup
    @repo = Dir.mktmpdir('ragent-approval-flow-test')
    @run_dir = Dir.mktmpdir('ragent-run-dir-test')
  end

  def teardown
    FileUtils.rm_rf(@repo)
    FileUtils.rm_rf(@run_dir)
  end

  def test_denial_sends_denied_message_to_model
    setup_git_repo
    tool_result = run_propose_patch(DIFF, input: "n\n")
    assert_match(/denied/i, tool_result)
  end

  def test_approval_sends_applied_message_to_model
    setup_git_repo
    tool_result = run_propose_patch(DIFF, auto_approve: true)
    assert_match(/applied/i, tool_result)
  end

  def test_approval_modifies_the_file
    setup_git_repo
    run_propose_patch(DIFF, auto_approve: true)
    assert_equal "new\n", File.read(File.join(@repo, 'lib/foo.rb'))
  end

  def test_denial_does_not_modify_files
    setup_git_repo
    run_propose_patch(DIFF, input: "n\n")
    assert_equal "old\n", File.read(File.join(@repo, 'lib/foo.rb'))
  end

  def test_inapplicable_patch_is_rejected_before_prompt
    setup_git_repo
    bad_context = "--- a/lib/foo.rb\n+++ b/lib/foo.rb\n@@ -1 +1 @@\n-does_not_exist\n+new\n"
    approver = Ragent::PatchApprover.new(
      auto_approve: false, input: StringIO.new("y\n"), output: StringIO.new
    )
    registry = Ragent.send(:build_registry, @repo, run_dir: @run_dir, approver: approver,
                                                   command_approver: Ragent::CommandApprover.new,
                                                   config: Ragent::Config.new(@repo))
    tool_result = run_agent(registry, bad_context)
    assert_match(/failed/i, tool_result)
  end

  private

  def run_propose_patch(diff, input: "n\n", auto_approve: false)
    approver = Ragent::PatchApprover.new(
      auto_approve: auto_approve, input: StringIO.new(input), output: StringIO.new
    )
    registry = Ragent.send(:build_registry, @repo, run_dir: @run_dir, approver: approver,
                                                   command_approver: Ragent::CommandApprover.new,
                                                   config: Ragent::Config.new(@repo))
    run_agent(registry, diff)
  end

  def run_agent(registry, diff)
    received = []
    responses = [
      Ragent::Response::ToolCall.new(tool: 'propose_patch', args: { 'diff' => diff }),
      Ragent::Response::Final.new(content: 'done')
    ]
    client = Ragent::ModelClient.new
    client.define_singleton_method(:call) do |msgs|
      received.replace(msgs)
      responses.shift
    end
    Ragent::AgentLoop.new(
      prompt: 'test', repo_root: @repo, model_client: client, tool_registry: registry
    ).run
    received.find { |m| m[:role] == 'tool' }&.fetch(:content, '')
  end

  def setup_git_repo
    FileUtils.mkdir_p(File.join(@repo, 'lib'))
    File.write(File.join(@repo, 'lib/foo.rb'), "old\n")
    system('git', '-C', @repo, 'init', out: File::NULL, err: File::NULL)
    system('git', '-C', @repo, 'config', 'user.email', 'test@t.com', out: File::NULL, err: File::NULL)
    system('git', '-C', @repo, 'config', 'user.name', 'Test', out: File::NULL, err: File::NULL)
    system('git', '-C', @repo, 'add', '.', out: File::NULL, err: File::NULL)
    system('git', '-C', @repo, 'commit', '-m', 'init', out: File::NULL, err: File::NULL)
  end
end
