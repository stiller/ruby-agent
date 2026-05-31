# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/ragent'

class TestRagent < Minitest::Test
  def test_run_prints_prompt
    Dir.mktmpdir do |dir|
      out, = capture_io { Ragent.run('hello', workspace: dir) }
      assert_match 'Received prompt: hello', out
    end
  end

  def test_run_prints_workspace
    Dir.mktmpdir do |dir|
      out, = capture_io { Ragent.run('hello', workspace: dir) }
      assert_match "Workspace: #{dir}", out
    end
  end

  def test_run_defaults_to_env_workspace
    out, = capture_io { Ragent.run('hello') }
    assert_match "Workspace: #{Ragent::Workspace::DEFAULT_PATH}", out
  end

  def test_run_with_longer_prompt
    Dir.mktmpdir do |dir|
      out, = capture_io { Ragent.run('build me a web app', workspace: dir) }
      assert_match 'Received prompt: build me a web app', out
    end
  end
end
