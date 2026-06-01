# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../../../lib/ragent'

class TestApplyPatch < Minitest::Test
  INITIAL_CONTENT = "def foo\n  'old'\nend\n"
  UPDATED_CONTENT = "def foo\n  'new'\nend\n"

  VALID_PATCH = <<~PATCH
    --- a/foo.rb
    +++ b/foo.rb
    @@ -1,3 +1,3 @@
     def foo
    -  'old'
    +  'new'
     end
  PATCH

  BARE_PATH_PATCH = <<~PATCH
    --- foo.rb
    +++ foo.rb
    @@ -1,3 +1,3 @@
     def foo
    -  'old'
    +  'new'
     end
  PATCH

  WRONG_COUNT_PATCH = <<~PATCH
    --- a/foo.rb
    +++ b/foo.rb
    @@ -1,3 +1,99 @@
    +# comment
     def foo
    -  'old'
    +  'new'
     end
  PATCH

  GIT_FORMAT_PATCH = <<~PATCH
    diff --git a/foo.rb b/foo.rb
    index abc1234..def5678 100644
    --- a/foo.rb
    +++ b/foo.rb
    @@ -1,3 +1,3 @@
     def foo
    -  'old'
    +  'new'
     end
  PATCH

  def setup
    @repo = Dir.mktmpdir('ragent-apply-patch-test')
    git('init')
    git('config', 'user.email', 'test@example.com')
    git('config', 'user.name', 'Test')
    File.write(File.join(@repo, 'foo.rb'), INITIAL_CONTENT)
    git('add', '.')
    git('commit', '-m', 'init')
    @patch_dir = Dir.mktmpdir('ragent-patch-dir-test')
    @tool = Ragent::Tools::ApplyPatch.new(@repo)
  end

  def teardown
    FileUtils.rm_rf(@repo)
    FileUtils.rm_rf(@patch_dir)
  end

  def test_applies_valid_patch
    result = @tool.call(save_patch(VALID_PATCH))
    assert_match(/applied/i, result.to_s)
  end

  def test_modifies_file_content
    @tool.call(save_patch(VALID_PATCH))
    assert_equal UPDATED_CONTENT, File.read(File.join(@repo, 'foo.rb'))
  end

  def test_result_mentions_modified_file
    result = @tool.call(save_patch(VALID_PATCH))
    assert_includes result.to_s, 'foo.rb'
  end

  def test_strips_git_headers_and_applies
    result = @tool.call(save_patch(GIT_FORMAT_PATCH))
    assert_match(/applied/i, result.to_s)
    assert_equal UPDATED_CONTENT, File.read(File.join(@repo, 'foo.rb'))
  end

  def test_fixes_miscounted_hunk_headers_and_applies
    result = @tool.call(save_patch(WRONG_COUNT_PATCH))
    assert_match(/applied/i, result.to_s)
  end

  def test_normalizes_bare_paths_and_applies
    result = @tool.call(save_patch(BARE_PATH_PATCH))
    assert_match(/applied/i, result.to_s)
    assert_equal UPDATED_CONTENT, File.read(File.join(@repo, 'foo.rb'))
  end

  def test_reapplication_fails
    patch_file = save_patch(VALID_PATCH)
    @tool.call(patch_file)
    result = @tool.call(patch_file)
    assert_match(/failed/i, result.to_s)
  end

  def test_returns_error_for_invalid_patch
    result = @tool.call(save_patch("not a real patch\n"))
    assert_match(/failed/i, result.to_s)
  end

  def test_error_does_not_modify_files
    @tool.call(save_patch("not a real patch\n"))
    assert_equal INITIAL_CONTENT, File.read(File.join(@repo, 'foo.rb'))
  end

  def test_check_returns_nil_for_valid_patch
    assert_nil @tool.check(save_patch(VALID_PATCH))
  end

  def test_check_returns_error_for_invalid_patch
    result = @tool.check(save_patch("not a real patch\n"))
    assert_match(/failed/i, result.to_s)
  end

  def test_check_does_not_modify_files
    @tool.check(save_patch(VALID_PATCH))
    assert_equal INITIAL_CONTENT, File.read(File.join(@repo, 'foo.rb'))
  end

  private

  def git(*args)
    system('git', '-C', @repo, *args, out: File::NULL, err: File::NULL)
  end

  def save_patch(content)
    path = File.join(@patch_dir, 'test.diff')
    File.write(path, content)
    path
  end
end
