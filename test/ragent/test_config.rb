# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'
require 'fileutils'
require_relative '../../lib/ragent'

class TestConfig < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('ragent-config-test')
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  # --- defaults when no file ---

  def test_defaults_when_no_file
    c = config
    assert_equal [], c.allowed_commands
    assert_equal [], c.ignored_paths
    assert_nil c.max_file_size
    assert_nil c.max_search_results
    assert_equal 'ask', c.approval_mode
  end

  # --- allowed_commands ---

  def test_loads_allowed_commands
    write_config("allowed_commands:\n  - bundle exec rake test\n  - npm test\n")
    assert_equal ['bundle exec rake test', 'npm test'], config.allowed_commands
  end

  def test_allowed_commands_invalid_type_raises
    write_config("allowed_commands: not-a-list\n")
    assert_raises(Ragent::ConfigError) { config }
  end

  def test_allowed_commands_non_string_element_raises
    write_config("allowed_commands:\n  - 42\n")
    assert_raises(Ragent::ConfigError) { config }
  end

  # --- ignored_paths ---

  def test_loads_ignored_paths
    write_config("ignored_paths:\n  - dist\n  - coverage\n")
    assert_equal %w[dist coverage], config.ignored_paths
  end

  def test_ignored_paths_invalid_type_raises
    write_config("ignored_paths: not-a-list\n")
    assert_raises(Ragent::ConfigError) { config }
  end

  def test_ignored_paths_non_string_element_raises
    write_config("ignored_paths:\n  - 42\n")
    assert_raises(Ragent::ConfigError) { config }
  end

  # --- max_file_size ---

  def test_loads_max_file_size
    write_config("max_file_size: 51200\n")
    assert_equal 51_200, config.max_file_size
  end

  def test_max_file_size_non_integer_raises
    write_config("max_file_size: big\n")
    assert_raises(Ragent::ConfigError) { config }
  end

  def test_max_file_size_zero_raises
    write_config("max_file_size: 0\n")
    assert_raises(Ragent::ConfigError) { config }
  end

  def test_max_file_size_negative_raises
    write_config("max_file_size: -1\n")
    assert_raises(Ragent::ConfigError) { config }
  end

  # --- max_search_results ---

  def test_loads_max_search_results
    write_config("max_search_results: 100\n")
    assert_equal 100, config.max_search_results
  end

  def test_max_search_results_non_integer_raises
    write_config("max_search_results: many\n")
    assert_raises(Ragent::ConfigError) { config }
  end

  def test_max_search_results_zero_raises
    write_config("max_search_results: 0\n")
    assert_raises(Ragent::ConfigError) { config }
  end

  # --- approval_mode ---

  def test_approval_mode_ask
    write_config("approval_mode: ask\n")
    assert_equal 'ask', config.approval_mode
  end

  def test_approval_mode_auto
    write_config("approval_mode: auto\n")
    assert_equal 'auto', config.approval_mode
  end

  def test_approval_mode_invalid_raises
    write_config("approval_mode: yolo\n")
    err = assert_raises(Ragent::ConfigError) { config }
    assert_includes err.message, 'approval_mode'
    assert_includes err.message, 'ask'
    assert_includes err.message, 'auto'
  end

  # --- blank / empty file ---

  def test_blank_file_uses_all_defaults
    write_config('')
    c = config
    assert_equal [], c.allowed_commands
    assert_equal 'ask', c.approval_mode
  end

  private

  def config
    Ragent::Config.new(@dir)
  end

  def write_config(content)
    File.write(File.join(@dir, Ragent::Config::FILENAME), content)
  end
end
