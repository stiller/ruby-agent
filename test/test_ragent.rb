# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../lib/ragent'

class TestRagent < Minitest::Test
  def test_run_prints_final_answer
    Dir.mktmpdir do |dir|
      out, = capture_io { Ragent.run('hello', workspace: dir) }
      assert_match '[fake] Received: hello', out
    end
  end

  def test_run_uses_prompt_in_answer
    Dir.mktmpdir do |dir|
      out, = capture_io { Ragent.run('build me a web app', workspace: dir) }
      assert_match '[fake] Received: build me a web app', out
    end
  end

  def test_run_returns_final_answer
    Dir.mktmpdir do |dir|
      out, = capture_io { Ragent.run('inspect this', workspace: dir) }
      assert_match '[fake] Received: inspect this', out
    end
  end

  def test_run_keeps_run_directory_by_default
    Dir.mktmpdir do |dir|
      capture_io { Ragent.run('hello', workspace: dir) }
      refute_empty Dir.glob(File.join(dir, '.ragent', 'runs', '*'))
    end
  end

  def test_run_deletes_run_directory_when_clean_runs
    Dir.mktmpdir do |dir|
      capture_io { Ragent.run('hello', workspace: dir, keep_runs: false) }
      assert_empty Dir.glob(File.join(dir, '.ragent', 'runs', '*'))
    end
  end
end
