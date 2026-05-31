require "minitest/autorun"
require_relative "../../lib/ragent"

class TestWorkspace < Minitest::Test
  def test_valid_path_returns_path
    Dir.mktmpdir do |dir|
      assert_equal dir, Ragent::Workspace.validate!(dir)
    end
  end

  def test_invalid_path_raises_workspace_error
    assert_raises(Ragent::WorkspaceError) do
      Ragent::Workspace.validate!("/nonexistent/path/ragent-test")
    end
  end

  def test_error_message_includes_the_bad_path
    err = assert_raises(Ragent::WorkspaceError) do
      Ragent::Workspace.validate!("/nonexistent/path/ragent-test")
    end
    assert_match "/nonexistent/path/ragent-test", err.message
  end

  def test_error_message_is_human_readable
    err = assert_raises(Ragent::WorkspaceError) do
      Ragent::Workspace.validate!("/nonexistent/path/ragent-test")
    end
    assert_match "does not exist or is not a directory", err.message
  end

  def test_default_path_reads_from_env
    assert_equal ENV.fetch("RAGENT_WORKSPACE", "/workspace"), Ragent::Workspace::DEFAULT_PATH
  end
end
