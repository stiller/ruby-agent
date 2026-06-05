# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../../lib/ragent'

class TestAgentInstructions < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('ragent-agent-instructions-test')
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_returns_empty_when_no_files_exist
    assert_equal [], load
  end

  def test_loads_root_agents_md
    write('AGENTS.md', 'always write tests')
    assert_equal 1, load.size
  end

  def test_root_agents_md_path_is_relative
    write('AGENTS.md', 'content')
    path, = load.first
    assert_equal 'AGENTS.md', path
  end

  def test_root_agents_md_content_is_read
    write('AGENTS.md', 'always write tests')
    _, content = load.first
    assert_equal 'always write tests', content
  end

  def test_loads_ragent_agents_md
    write('.ragent/AGENTS.md', 'prefer small commits')
    assert_equal 1, load.size
  end

  def test_ragent_agents_md_path_is_relative
    write('.ragent/AGENTS.md', 'content')
    path, = load.first
    assert_equal File.join('.ragent', 'AGENTS.md'), path
  end

  def test_loads_both_files_when_both_exist
    write('AGENTS.md', 'root instructions')
    write('.ragent/AGENTS.md', 'ragent instructions')
    assert_equal 2, load.size
  end

  def test_root_agents_md_comes_before_ragent_agents_md
    write('AGENTS.md', 'root')
    write('.ragent/AGENTS.md', 'ragent')
    paths = load.map(&:first)
    assert_equal 'AGENTS.md', paths[0]
    assert_equal File.join('.ragent', 'AGENTS.md'), paths[1]
  end

  def test_does_not_load_agents_md_from_subdirectory
    write('subdir/AGENTS.md', 'should not load')
    assert_equal [], load
  end

  private

  def load
    Ragent::AgentInstructions.new(@dir).load
  end

  def write(relative_path, content)
    full = File.join(@dir, relative_path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end
end
