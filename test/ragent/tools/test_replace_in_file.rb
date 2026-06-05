# frozen_string_literal: true

require_relative '../../test_helper'
require 'tmpdir'
require 'fileutils'
require_relative '../../../lib/ragent'

class TestReplaceInFile < Minitest::Test
  def setup
    @repo = Dir.mktmpdir('ragent-replace-test')
    @run_dir = Dir.mktmpdir('ragent-replace-run')
    setup_git_repo
  end

  def teardown
    FileUtils.rm_rf(@repo)
    FileUtils.rm_rf(@run_dir)
  end

  # --- basic replacement ---

  def test_returns_result_on_success
    write('app.rb', "def hello\n  puts 'hi'\nend\n")
    result = call('app.rb', "puts 'hi'", "puts 'hello'")
    assert_instance_of Ragent::Tools::ReplaceInFile::Result, result
  end

  def test_result_contains_correct_path
    write('app.rb', "old text\n")
    result = call('app.rb', 'old text', 'new text')
    assert_equal 'app.rb', result.path
  end

  def test_result_contains_patch_file_path
    write('app.rb', "old text\n")
    result = call('app.rb', 'old text', 'new text')
    assert File.exist?(result.patch_file), "patch file should exist at #{result.patch_file}"
  end

  def test_patch_file_contains_unified_diff
    write('app.rb', "old text\n")
    result = call('app.rb', 'old text', 'new text')
    diff = File.read(result.patch_file)
    assert_match(/^---/, diff)
    assert_match(/^\+\+\+/, diff)
    assert_match(/^-old text/, diff)
    assert_match(/^\+new text/, diff)
  end

  def test_patch_file_has_correct_labels
    write('app.rb', "old text\n")
    result = call('app.rb', 'old text', 'new text')
    diff = File.read(result.patch_file)
    assert_match(%r{--- a/app\.rb}, diff)
    assert_match(%r{\+\+\+ b/app\.rb}, diff)
  end

  def test_patch_files_are_numbered_sequentially
    write('a.rb', "old\n")
    write('b.rb', "old\n")
    r1 = call('a.rb', 'old', 'new1')
    r2 = call('b.rb', 'old', 'new2')
    assert_match(/replace_0\.patch$/, r1.patch_file)
    assert_match(/replace_1\.patch$/, r2.patch_file)
  end

  # --- uniqueness ---

  def test_error_when_old_text_not_found
    write('app.rb', "some content\n")
    result = call('app.rb', 'missing text', 'new')
    assert_instance_of Ragent::Tools::ReplaceInFile::Error, result
    assert_match(/not found/, result.to_s)
  end

  def test_error_when_old_text_appears_multiple_times
    write('app.rb', "foo\nfoo\n")
    result = call('app.rb', 'foo', 'bar')
    assert_instance_of Ragent::Tools::ReplaceInFile::Error, result
    assert_match(/appears 2 times/, result.to_s)
    assert_match(/must be unique/, result.to_s)
  end

  def test_succeeds_when_old_text_appears_exactly_once
    write('app.rb', "foo\nbar\n")
    result = call('app.rb', 'foo', 'baz')
    assert_instance_of Ragent::Tools::ReplaceInFile::Result, result
  end

  # --- file not found ---

  def test_error_when_file_does_not_exist
    result = call('nonexistent.rb', 'old', 'new')
    assert_instance_of Ragent::Tools::ReplaceInFile::Error, result
    assert_match(/not found/i, result.to_s)
  end

  # --- path safety ---

  def test_error_for_absolute_path
    result = call('/etc/passwd', 'root', 'hacked')
    assert_instance_of Ragent::Tools::ReplaceInFile::Error, result
    assert_match(/relative/, result.to_s)
  end

  def test_error_for_path_with_parent_traversal
    result = call('../outside.rb', 'old', 'new')
    assert_instance_of Ragent::Tools::ReplaceInFile::Error, result
    assert_match(/outside the repository root/, result.to_s)
  end

  def test_error_for_deeply_nested_traversal
    result = call('a/../../outside.rb', 'old', 'new')
    assert_instance_of Ragent::Tools::ReplaceInFile::Error, result
    assert_match(/outside the repository root/, result.to_s)
  end

  # --- integration with apply ---

  def test_apply_approved_patch_modifies_file
    write('app.rb', "old text\n")
    result = call('app.rb', 'old text', 'new text')
    assert_instance_of Ragent::Tools::ReplaceInFile::Result, result

    applier = Ragent::Tools::ApplyPatch.new(@repo)
    apply_result = applier.call(result.patch_file)
    assert_instance_of Ragent::Tools::ApplyPatch::Result, apply_result
    assert_equal "new text\n", File.read(File.join(@repo, 'app.rb'))
  end

  private

  def write(relative_path, content)
    full = File.join(@repo, relative_path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  def call(path, old_text, new_text)
    Ragent::Tools::ReplaceInFile.new(@repo, run_dir: @run_dir).call(path, old_text, new_text)
  end

  def setup_git_repo
    system('git', '-C', @repo, 'init', out: File::NULL, err: File::NULL)
    system('git', '-C', @repo, 'config', 'user.email', 'test@t.com', out: File::NULL, err: File::NULL)
    system('git', '-C', @repo, 'config', 'user.name', 'Test', out: File::NULL, err: File::NULL)
  end
end
