require "minitest/autorun"
require_relative "../lib/ragent"

class TestRagent < Minitest::Test
  def test_run_prints_prompt
    out, = capture_io { Ragent.run("hello", workspace: "/tmp/test-repo") }
    assert_match "Received prompt: hello", out
  end

  def test_run_prints_workspace
    out, = capture_io { Ragent.run("hello", workspace: "/tmp/test-repo") }
    assert_match "Workspace: /tmp/test-repo", out
  end

  def test_run_defaults_to_env_workspace
    out, = capture_io { Ragent.run("hello") }
    assert_match "Workspace: #{Ragent::DEFAULT_WORKSPACE}", out
  end

  def test_run_with_longer_prompt
    out, = capture_io { Ragent.run("build me a web app", workspace: "/tmp/test-repo") }
    assert_match "Received prompt: build me a web app", out
  end
end
