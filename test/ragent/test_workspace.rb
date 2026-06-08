# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'
require 'fileutils'
require_relative '../../lib/ragent'

class TestWorkspace < Minitest::Test
  def test_valid_path_returns_path
    Dir.mktmpdir do |dir|
      assert_equal dir, Ragent::Workspace.validate!(dir)
    end
  end

  def test_invalid_path_raises_workspace_error
    assert_raises(Ragent::WorkspaceError) do
      Ragent::Workspace.validate!('/nonexistent/path/ragent-test')
    end
  end

  def test_error_message_includes_the_bad_path
    err = assert_raises(Ragent::WorkspaceError) do
      Ragent::Workspace.validate!('/nonexistent/path/ragent-test')
    end
    assert_match '/nonexistent/path/ragent-test', err.message
  end

  def test_error_message_is_human_readable
    err = assert_raises(Ragent::WorkspaceError) do
      Ragent::Workspace.validate!('/nonexistent/path/ragent-test')
    end
    assert_match 'does not exist or is not a directory', err.message
  end

  def test_default_path_reads_from_env
    assert_equal ENV.fetch('RAGENT_WORKSPACE', '/workspace'), Ragent::Workspace::DEFAULT_PATH
  end

  def test_ensure_ragent_ignored_creates_gitignore_when_absent
    Dir.mktmpdir do |dir|
      Ragent::Workspace.ensure_ragent_ignored!(dir)
      assert_includes File.read(File.join(dir, '.gitignore')), '.ragent/'
    end
  end

  def test_ensure_ragent_ignored_appends_to_existing_gitignore
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, '.gitignore'), "*.log\n")
      Ragent::Workspace.ensure_ragent_ignored!(dir)
      content = File.read(File.join(dir, '.gitignore'))
      assert_includes content, '*.log'
      assert_includes content, '.ragent/'
    end
  end

  def test_ensure_ragent_ignored_does_not_duplicate_entry
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, '.gitignore'), ".ragent/\n")
      Ragent::Workspace.ensure_ragent_ignored!(dir)
      count = File.read(File.join(dir, '.gitignore')).lines.count { |l| l.chomp == '.ragent/' }
      assert_equal 1, count
    end
  end

  def test_ensure_ragent_ignored_accepts_entry_without_trailing_slash
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, '.gitignore'), ".ragent\n")
      Ragent::Workspace.ensure_ragent_ignored!(dir)
      count = File.read(File.join(dir, '.gitignore')).lines.count { |l| l.chomp.start_with?('.ragent') }
      assert_equal 1, count
    end
  end

  def test_ensure_ragent_ignored_is_silent_on_read_only_workspace
    skip 'cannot test read-only filesystem as root' if Process.uid.zero?
    Dir.mktmpdir do |dir|
      FileUtils.chmod(0o555, dir)
      assert_nil Ragent::Workspace.ensure_ragent_ignored!(dir)
    ensure
      FileUtils.chmod(0o755, dir)
    end
  end

  def test_resolve_artifact_dir_defaults_to_ragent_runs_under_workspace
    Dir.mktmpdir do |dir|
      result = Ragent::Workspace.resolve_artifact_dir(dir)
      assert result.start_with?(dir), "expected #{result} to be under #{dir}"
      assert Dir.exist?(result)
    end
  end

  def test_resolve_artifact_dir_returns_nil_for_read_only_workspace
    skip 'cannot test read-only filesystem as root' if Process.uid.zero?
    Dir.mktmpdir do |dir|
      FileUtils.chmod(0o555, dir)
      result = Ragent::Workspace.resolve_artifact_dir(dir)
      assert_nil result
    ensure
      FileUtils.chmod(0o755, dir)
    end
  end

  def test_resolve_artifact_dir_returns_nil_when_runs_dir_exists_but_not_writable
    skip 'cannot test read-only filesystem as root' if Process.uid.zero?
    Dir.mktmpdir do |dir|
      runs_dir = File.join(dir, '.ragent', 'runs')
      FileUtils.mkdir_p(runs_dir)
      FileUtils.chmod(0o555, runs_dir)
      result = Ragent::Workspace.resolve_artifact_dir(dir)
      assert_nil result
    ensure
      FileUtils.chmod(0o755, runs_dir)
    end
  end

  def test_resolve_artifact_dir_explicit_internal_path
    Dir.mktmpdir do |dir|
      artifact_dir = File.join(dir, 'my-artifacts')
      result = Ragent::Workspace.resolve_artifact_dir(dir, artifact_dir: artifact_dir)
      assert_equal File.expand_path(artifact_dir), result
      assert Dir.exist?(result)
    end
  end

  def test_resolve_artifact_dir_external_path_requires_flag
    Dir.mktmpdir do |workspace|
      Dir.mktmpdir do |external|
        assert_raises(Ragent::WorkspaceError) do
          Ragent::Workspace.resolve_artifact_dir(workspace, artifact_dir: external)
        end
      end
    end
  end

  def test_resolve_artifact_dir_external_path_allowed_with_flag
    Dir.mktmpdir do |workspace|
      Dir.mktmpdir do |external|
        result = Ragent::Workspace.resolve_artifact_dir(workspace, artifact_dir: external, allow_external: true)
        assert_equal File.expand_path(external), result
      end
    end
  end
end
