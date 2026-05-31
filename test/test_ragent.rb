require "minitest/autorun"
require_relative "../lib/ragent"

class TestRagent < Minitest::Test
  def test_run_prints_prompt
    out, = capture_io { Ragent.run("hello") }
    assert_equal "Received prompt: hello\n", out
  end

  def test_run_with_longer_prompt
    out, = capture_io { Ragent.run("build me a web app") }
    assert_equal "Received prompt: build me a web app\n", out
  end
end
