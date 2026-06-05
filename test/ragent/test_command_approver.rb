# frozen_string_literal: true

require 'minitest/autorun'
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

  private

  def approver_with(input:, output: StringIO.new)
    Ragent::CommandApprover.new(
      input: StringIO.new(input), output: output
    )
  end
end
