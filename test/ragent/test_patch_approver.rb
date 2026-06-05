# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'
require 'fileutils'
require_relative '../../lib/ragent'

class TestPatchApprover < Minitest::Test
  SAMPLE_DIFF = "--- a/foo.rb\n+++ b/foo.rb\n@@ -1 +1 @@\n-old\n+new\n"

  def setup
    @dir = Dir.mktmpdir('ragent-approver-test')
    @patch_file = File.join(@dir, 'test.diff')
    File.write(@patch_file, SAMPLE_DIFF)
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  # --- y/N responses ---

  def test_y_approves
    assert approver_with('y').call(@patch_file)
  end

  def test_capital_y_approves
    assert approver_with('Y').call(@patch_file)
  end

  def test_n_denies
    refute approver_with('n').call(@patch_file)
  end

  def test_empty_input_denies
    refute approver_with('').call(@patch_file)
  end

  def test_eof_denies
    refute Ragent::PatchApprover.new(input: StringIO.new(''), output: StringIO.new).call(@patch_file)
  end

  # --- auto-approve ---

  def test_auto_approve_returns_true
    assert auto_approver.call(@patch_file)
  end

  def test_auto_approve_does_not_read_input
    input = StringIO.new('')
    Ragent::PatchApprover.new(auto_approve: true, input: input, output: StringIO.new).call(@patch_file)
    assert_equal 0, input.pos
  end

  # --- output ---

  def test_prints_diff_content
    out = capture_output { |a| a.call(@patch_file) }
    assert_includes out, 'foo.rb'
  end

  def test_prints_prompt_with_default_no
    out = capture_output { |a| a.call(@patch_file) }
    assert_match(/apply this patch\?/i, out)
    assert_includes out, '[y/N]'
  end

  def test_auto_approve_prints_diff_but_no_prompt
    out = StringIO.new
    Ragent::PatchApprover.new(auto_approve: true, input: StringIO.new, output: out).call(@patch_file)
    assert_includes out.string, 'foo.rb'
    refute_match(%r{\[y/N\]}, out.string)
  end

  private

  def approver_with(response)
    Ragent::PatchApprover.new(input: StringIO.new("#{response}\n"), output: StringIO.new)
  end

  def auto_approver
    Ragent::PatchApprover.new(auto_approve: true, input: StringIO.new, output: StringIO.new)
  end

  def capture_output
    out = StringIO.new
    a = Ragent::PatchApprover.new(input: StringIO.new("n\n"), output: out)
    yield a
    out.string
  end
end
