# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'open3'
require_relative '../../lib/ragent'

class TestRollback < Minitest::Test
  INITIAL = "def foo\n  'old'\nend\n"
  UPDATED = "def foo\n  'new'\nend\n"

  PATCH = <<~PATCH
    --- a/foo.rb
    +++ b/foo.rb
    @@ -1,3 +1,3 @@
     def foo
    -  'old'
    +  'new'
     end
  PATCH

  def setup
    @repo = Dir.mktmpdir('ragent-rollback-repo')
    @run_dir = Dir.mktmpdir('ragent-rollback-run')
    git('init')
    git('config', 'user.email', 'test@t.com')
    git('config', 'user.name', 'Test')
    File.write(File.join(@repo, 'foo.rb'), INITIAL)
    git('add', '.')
    git('commit', '-m', 'init')
  end

  def teardown
    FileUtils.rm_rf(@repo)
    FileUtils.rm_rf(@run_dir)
  end

  def test_rollback_reverses_the_patch
    apply_and_checkpoint
    rollback(input: "y\n")
    assert_equal INITIAL, File.read(File.join(@repo, 'foo.rb'))
  end

  def test_rollback_returns_success_message
    apply_and_checkpoint
    result = rollback(input: "y\n")
    assert_match(/rolled back/i, result)
  end

  def test_cancelled_does_not_modify_file
    apply_and_checkpoint
    rollback(input: "n\n")
    assert_equal UPDATED, File.read(File.join(@repo, 'foo.rb'))
  end

  def test_cancelled_returns_cancelled_message
    apply_and_checkpoint
    result = rollback(input: "n\n")
    assert_match(/cancel/i, result)
  end

  def test_failed_rollback_returns_manual_instructions
    write_checkpoint(PATCH)
    result = rollback(input: "y\n")
    assert_match(/manual/i, result)
  end

  def test_failed_rollback_mentions_branch
    write_checkpoint(PATCH)
    result = rollback(input: "y\n")
    assert_match(/branch/i, result)
  end

  def test_raises_on_missing_checkpoint
    assert_raises(Ragent::Rollback::CheckpointMissing) do
      rollback(input: "y\n")
    end
  end

  private

  def rollback(input:)
    Ragent::Rollback.new(@repo).call(
      @run_dir,
      input: StringIO.new(input),
      output: StringIO.new
    )
  end

  def apply_and_checkpoint
    Open3.capture2e('git', '-C', @repo, 'apply', '-', stdin_data: PATCH)
    write_checkpoint(PATCH)
  end

  def write_checkpoint(patch)
    data = { branch: 'main', status: '', diff: '', patch: patch }
    File.write(File.join(@run_dir, 'checkpoint-20260601-000000.json'), JSON.generate(data))
  end

  def git(*args)
    system('git', '-C', @repo, *args, out: File::NULL, err: File::NULL)
  end
end
