# frozen_string_literal: true

require_relative '../../test_helper'
require 'tmpdir'
require 'fileutils'
require_relative '../../../lib/ragent'

class TestProposePatch < Minitest::Test
  VALID_DIFF = <<~DIFF
    --- a/lib/foo.rb
    +++ b/lib/foo.rb
    @@ -1,3 +1,4 @@
     def foo
    -  'old'
    +  'new'
     end
  DIFF

  def setup
    @repo_dir = Dir.mktmpdir('ragent-patch-repo')
    @run_dir  = Dir.mktmpdir('ragent-patch-run')
    @tool = Ragent::Tools::ProposePatch.new(@repo_dir, run_dir: @run_dir)
  end

  def teardown
    FileUtils.rm_rf(@repo_dir)
    FileUtils.rm_rf(@run_dir)
  end

  # --- happy path ---

  def test_result_says_proposed_not_applied
    result = @tool.call(VALID_DIFF)
    assert_match(/proposed/i, result.to_s)
    assert_match(/not applied/i, result.to_s)
  end

  def test_saves_patch_file_with_correct_content
    result = @tool.call(VALID_DIFF)
    assert File.exist?(result.patch_file)
    assert_equal VALID_DIFF, File.read(result.patch_file)
  end

  def test_patch_file_saved_inside_run_dir
    result = @tool.call(VALID_DIFF)
    assert result.patch_file.start_with?(@run_dir)
  end

  def test_patch_file_has_diff_extension
    result = @tool.call(VALID_DIFF)
    assert result.patch_file.end_with?('.diff')
  end

  def test_accepts_new_file_diff_with_dev_null
    diff = <<~DIFF
      --- /dev/null
      +++ b/lib/new_file.rb
      @@ -0,0 +1 @@
      +hello
    DIFF
    result = @tool.call(diff)
    assert_match(/proposed/i, result.to_s)
  end

  def test_accepts_deleted_file_diff_with_dev_null
    diff = <<~DIFF
      --- a/lib/old_file.rb
      +++ /dev/null
      @@ -1 +0,0 @@
      -goodbye
    DIFF
    result = @tool.call(diff)
    assert_match(/proposed/i, result.to_s)
  end

  # --- path escapes repo root ---

  def test_rejects_path_with_dotdot_traversal
    diff = "--- a/../etc/passwd\n+++ b/../etc/passwd\n"
    result = @tool.call(diff)
    assert_match(/outside/i, result.to_s)
  end

  def test_rejects_absolute_path_in_diff
    diff = "--- a/lib/foo.rb\n+++ /etc/passwd\n"
    result = @tool.call(diff)
    assert_match(/rejected/i, result.to_s)
  end

  # --- ignored directories ---

  def test_rejects_git_directory
    diff = "--- a/.git/config\n+++ b/.git/config\n"
    result = @tool.call(diff)
    assert_match(/ignored/i, result.to_s)
    assert_match(/\.git/, result.to_s)
  end

  def test_rejects_node_modules
    diff = "--- a/node_modules/pkg/index.js\n+++ b/node_modules/pkg/index.js\n"
    result = @tool.call(diff)
    assert_match(/ignored/i, result.to_s)
  end

  def test_rejects_vendor_directory
    diff = "--- a/vendor/gems/foo.rb\n+++ b/vendor/gems/foo.rb\n"
    result = @tool.call(diff)
    assert_match(/ignored/i, result.to_s)
  end

  # --- malformed diff ---

  def test_rejects_diff_with_no_file_paths
    result = @tool.call("@@ -1,3 +1,4 @@\n-old\n+new\n")
    assert_match(/no file paths/i, result.to_s)
  end

  def test_rejects_nil_diff
    result = @tool.call(nil)
    assert_match(/no file paths/i, result.to_s)
  end
end
