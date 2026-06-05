# frozen_string_literal: true

require_relative '../test_helper'
require 'stringio'
require_relative '../../lib/ragent'

class TestCommandApprover < Minitest::Test
  Proposal = Struct.new(:command, :reason)

  def proposal
    Proposal.new('echo hello', 'greet the user')
  end

  def test_returns_true_on_yes
    approver = approver_with(input: "y\n")
    assert approver.call(proposal)
  end

  def test_returns_false_on_no
    approver = approver_with(input: "n\n")
    refute approver.call(proposal)
  end

  def test_returns_false_on_empty_input
    approver = approver_with(input: "\n")
    refute approver.call(proposal)
  end

  def test_returns_false_on_eof
    approver = approver_with(input: '')
    refute approver.call(proposal)
  end

  def test_auto_approve_with_allow_commands
    approver = Ragent::CommandApprover.new(
      auto_approve: true, allow_commands: true,
      input: StringIO.new(''), output: StringIO.new
    )
    assert approver.call(proposal)
  end

  def test_auto_approve_without_allow_commands_still_prompts
    approver = Ragent::CommandApprover.new(
      auto_approve: true, allow_commands: false,
      input: StringIO.new("n\n"), output: StringIO.new
    )
    refute approver.call(proposal)
  end

  def test_output_includes_command
    out = StringIO.new
    approver_with(input: "n\n", output: out).call(proposal)
    assert_includes out.string, 'echo hello'
  end

  def test_output_includes_reason
    out = StringIO.new
    approver_with(input: "n\n", output: out).call(proposal)
    assert_includes out.string, 'greet the user'
  end

  def test_allowlisted_exact_command_auto_approves
    approver = approver_with_allowlist(['echo hello'], input: '')
    assert approver.call(proposal)
  end

  def test_allowlisted_prefix_auto_approves
    approver = approver_with_allowlist(['bundle exec rake'], input: '')
    assert approver.call(Proposal.new('bundle exec rake test', 'run tests'))
  end

  def test_allowlisted_prefix_does_not_match_different_command
    approver = approver_with_allowlist(['echo'], input: "n\n")
    refute approver.call(Proposal.new('echo_server start', 'start server'))
  end

  def test_non_allowlisted_command_still_prompts_and_denies
    approver = approver_with_allowlist(['npm test'], input: "n\n")
    refute approver.call(proposal)
  end

  def test_non_allowlisted_command_still_prompts_and_approves
    approver = approver_with_allowlist(['npm test'], input: "y\n")
    assert approver.call(proposal)
  end

  def test_empty_allowlist_has_no_effect
    approver = approver_with_allowlist([], input: "n\n")
    refute approver.call(proposal)
  end

  private

  def approver_with(input:, output: StringIO.new)
    Ragent::CommandApprover.new(
      input: StringIO.new(input), output: output
    )
  end

  def approver_with_allowlist(allowed_commands, input:, output: StringIO.new)
    Ragent::CommandApprover.new(
      allowed_commands: allowed_commands,
      input: StringIO.new(input), output: output
    )
  end
end
