# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'json'
require_relative '../../lib/ragent'

class TestCheckpoint < Minitest::Test
  def setup
    @repo = Dir.mktmpdir('ragent-checkpoint-repo')
    @run_dir = Dir.mktmpdir('ragent-checkpoint-run')
    @patch = File.join(@run_dir, 'test.diff')
    File.write(@patch, "--- a/foo.rb\n+++ b/foo.rb\n@@ -1 +1 @@\n-old\n+new\n")
  end

  def teardown
    FileUtils.rm_rf(@repo)
    FileUtils.rm_rf(@run_dir)
  end

  def test_git_repo_false_for_plain_dir
    refute checkpoint.git_repo?
  end

  def test_git_repo_true_for_git_repo
    init_git
    assert checkpoint.git_repo?
  end

  def test_save_creates_checkpoint_file
    init_git
    checkpoint.save(@patch)
    assert_equal 1, checkpoint_files.length
  end

  def test_save_records_required_fields
    init_git
    checkpoint.save(@patch)
    data = JSON.parse(File.read(checkpoint_files.first))
    assert data.key?('branch')
    assert data.key?('status')
    assert data.key?('diff')
    assert data.key?('patch')
  end

  def test_save_records_branch_as_string
    init_git
    checkpoint.save(@patch)
    data = JSON.parse(File.read(checkpoint_files.first))
    refute_empty data['branch']
  end

  def test_save_records_patch_content
    init_git
    checkpoint.save(@patch)
    data = JSON.parse(File.read(checkpoint_files.first))
    assert_equal File.read(@patch), data['patch']
  end

  def test_save_is_noop_for_non_git_repo
    checkpoint.save(@patch)
    assert_empty checkpoint_files
  end

  def test_git_repo_result_is_memoized
    init_git
    cp = checkpoint
    first = cp.git_repo?
    # Corrupt the repo path; memoized result should be unchanged
    FileUtils.rm_rf(File.join(@repo, '.git'))
    assert_equal first, cp.git_repo?
  end

  private

  def checkpoint
    Ragent::Checkpoint.new(@repo, run_dir: @run_dir)
  end

  def checkpoint_files
    Dir.glob(File.join(@run_dir, 'checkpoint-*.json'))
  end

  def init_git
    system('git', '-C', @repo, 'init', out: File::NULL, err: File::NULL)
    system('git', '-C', @repo, 'config', 'user.email', 'test@t.com', out: File::NULL, err: File::NULL)
    system('git', '-C', @repo, 'config', 'user.name', 'Test', out: File::NULL, err: File::NULL)
  end
end
