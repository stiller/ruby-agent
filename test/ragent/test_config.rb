# frozen_string_literal: true

require 'minitest/autorun'
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

  def test_allowed_commands_defaults_to_empty_when_no_file
    assert_equal [], Ragent::Config.new(@dir).allowed_commands
  end

  def test_allowed_commands_defaults_to_empty_when_file_is_blank
    write_config('')
    assert_equal [], Ragent::Config.new(@dir).allowed_commands
  end

  def test_allowed_commands_defaults_to_empty_when_key_absent
    write_config("other_key: value\n")
    assert_equal [], Ragent::Config.new(@dir).allowed_commands
  end

  def test_loads_allowed_commands
    write_config("allowed_commands:\n  - bundle exec rake test\n  - npm test\n")
    assert_equal ['bundle exec rake test', 'npm test'], Ragent::Config.new(@dir).allowed_commands
  end

  def test_single_allowed_command
    write_config("allowed_commands:\n  - pytest\n")
    assert_equal ['pytest'], Ragent::Config.new(@dir).allowed_commands
  end

  private

  def write_config(content)
    File.write(File.join(@dir, Ragent::Config::FILENAME), content)
  end
end
