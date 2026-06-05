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
end
