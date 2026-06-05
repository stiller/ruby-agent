# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../../../lib/ragent'

class TestReplaceAllInFile < Minitest::Test
  def setup
    @repo = Dir.mktmpdir('ragent-replace-all-test')
    @run_dir = Dir.mktmpdir('ragent-replace-all-run')
    setup_git_repo
  end

  def teardown
    FileUtils.rm_rf(@repo)
    FileUtils.rm_rf(@run_dir)
  end

  # --- basic replacement ---

  def test_returns_result_on_success
    write('app.rb', "foo\nfoo\n")
    assert_instance_of Ragent::Tools::ReplaceAllInFile::Result, call('app.rb', 'foo', 'bar')
  end

  def test_result_contains_correct_path
    write('app.rb', "foo\n")
    assert_equal 'app.rb', call('app.rb', 'foo', 'bar').path
  end

  def test_result_contains_count_of_replacements
    write('app.rb', "foo\nfoo\nfoo\n")
    assert_equal 3, call('app.rb', 'foo', 'bar').replacement_count
  end

  def test_result_count_is_one_for_single_occurrence
    write('app.rb', "foo\nbar\n")
    assert_equal 1, call('app.rb', 'foo', 'baz').replacement_count
  end

  def test_result_contains_patch_file_path
    write('app.rb', "foo\n")
    result = call('app.rb', 'foo', 'bar')
    assert File.exist?(result.patch_file), 'patch file should exist'
  end

  def test_patch_file_contains_unified_diff
    write('app.rb', "old\nold\n")
    result = call('app.rb', 'old', 'new')
    diff = File.read(result.patch_file)
    assert_match(/^---/, diff)
    assert_match(/^\+\+\+/, diff)
    assert_match(/^-old/, diff)
    assert_match(/^\+new/, diff)
  end

  def test_patch_files_are_numbered_sequentially
    write('a.rb', "foo\n")
    write('b.rb', "foo\n")
    r1 = call('a.rb', 'foo', 'bar')
    r2 = call('b.rb', 'foo', 'baz')
    assert_match(/replace_all_0\.patch$/, r1.patch_file)
    assert_match(/replace_all_1\.patch$/, r2.patch_file)
  end

  # --- replaces all occurrences ---

  def test_replaces_multiple_occurrences
    write('app.rb', "foo\nfoo\nfoo\n")
    result = call('app.rb', 'foo', 'bar')
    diff = File.read(result.patch_file)
    assert_equal 3, diff.scan(/^\+bar/).length
  end

  def test_apply_replaces_all_in_file
    write('app.rb', "foo\nfoo\n")
    result = call('app.rb', 'foo', 'bar')
    Ragent::Tools::ApplyPatch.new(@repo).call(result.patch_file)
    assert_equal "bar\nbar\n", File.read(File.join(@repo, 'app.rb'))
  end

  # --- error cases ---

  def test_error_when_old_text_not_found
    write('app.rb', "something else\n")
    result = call('app.rb', 'missing', 'new')
    assert_instance_of Ragent::Tools::ReplaceAllInFile::Error, result
    assert_match(/not found/, result.to_s)
  end

  def test_error_when_file_does_not_exist
    result = call('nonexistent.rb', 'old', 'new')
    assert_instance_of Ragent::Tools::ReplaceAllInFile::Error, result
    assert_match(/not found/i, result.to_s)
  end

  # --- path safety ---

  def test_error_for_absolute_path
    result = call('/etc/passwd', 'root', 'hacked')
    assert_instance_of Ragent::Tools::ReplaceAllInFile::Error, result
    assert_match(/relative/, result.to_s)
  end

  def test_error_for_path_with_parent_traversal
    result = call('../outside.rb', 'old', 'new')
    assert_instance_of Ragent::Tools::ReplaceAllInFile::Error, result
    assert_match(/outside the repository root/, result.to_s)
  end

  private

  def write(relative_path, content)
    full = File.join(@repo, relative_path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  def call(path, old_text, new_text)
    Ragent::Tools::ReplaceAllInFile.new(@repo, run_dir: @run_dir).call(path, old_text, new_text)
  end

  def setup_git_repo
    system('git', '-C', @repo, 'init', out: File::NULL, err: File::NULL)
    system('git', '-C', @repo, 'config', 'user.email', 'test@t.com', out: File::NULL, err: File::NULL)
    system('git', '-C', @repo, 'config', 'user.name', 'Test', out: File::NULL, err: File::NULL)
  end
end
