# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../../../lib/ragent'

class TestReadFile < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('ragent-read-test')
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  # --- normal reads ---

  def test_returns_file_content
    write('hello.rb', "puts 'hello'")
    assert_equal "puts 'hello'", read('hello.rb').content
  end

  def test_returns_correct_path
    write('hello.rb', '')
    assert_equal 'hello.rb', read('hello.rb').path
  end

  def test_returns_correct_size
    write('hello.rb', 'abc')
    assert_equal 3, read('hello.rb').byte_size
  end

  def test_truncated_is_always_false
    write('hello.rb', 'abc')
    assert_equal false, read('hello.rb').truncated
  end

  def test_reads_file_in_subdirectory
    FileUtils.mkdir_p(File.join(@dir, 'lib/ragent'))
    write('lib/ragent/runner.rb', 'module Ragent; end')
    assert_equal 'module Ragent; end', read('lib/ragent/runner.rb').content
  end

  def test_reads_empty_file
    write('empty.rb', '')
    result = read('empty.rb')
    assert_equal '', result.content
    assert_equal 0, result.byte_size
  end

  # --- missing files ---

  def test_raises_for_missing_file
    assert_raises(Errno::ENOENT) { read('nonexistent.rb') }
  end

  # --- absolute paths ---

  def test_raises_for_absolute_path
    err = assert_raises(ArgumentError) { read('/etc/passwd') }
    assert_match 'must be relative', err.message
  end

  # --- path traversal ---

  def test_raises_for_dotdot_in_path
    err = assert_raises(ArgumentError) { read('../outside.rb') }
    assert_match "'..'", err.message
  end

  def test_raises_for_dotdot_in_nested_path
    assert_raises(ArgumentError) { read('lib/../../outside.rb') }
  end

  def test_dotdot_as_filename_prefix_is_allowed
    write('..hidden.rb', 'ok')
    assert_equal 'ok', read('..hidden.rb').content
  end

  # --- large files ---

  def test_raises_for_file_exceeding_limit
    write('big.rb', 'x' * 101)
    err = assert_raises(Ragent::FileTooLargeError) do
      reader(max_size: 100).call('big.rb')
    end
    assert_match 'big.rb', err.message
    assert_match 'limit', err.message
  end

  def test_reads_file_exactly_at_limit
    write('edge.rb', 'x' * 100)
    result = reader(max_size: 100).call('edge.rb')
    assert_equal 100, result.byte_size
  end

  # --- symlink safety ---

  def test_raises_for_symlink_escaping_repo
    outside = Dir.mktmpdir('ragent-outside')
    File.write(File.join(outside, 'secret.txt'), 'secret')
    File.symlink(File.join(outside, 'secret.txt'), File.join(@dir, 'escape.txt'))

    err = assert_raises(ArgumentError) { read('escape.txt') }
    assert_match 'escapes the repo root', err.message
  ensure
    FileUtils.rm_rf(outside)
  end

  def test_reads_symlink_inside_repo
    write('real.rb', 'hello')
    File.symlink(File.join(@dir, 'real.rb'), File.join(@dir, 'link.rb'))
    assert_equal 'hello', read('link.rb').content
  end

  def test_raises_for_broken_symlink
    File.symlink('/nonexistent/path', File.join(@dir, 'broken.rb'))
    assert_raises(Errno::ENOENT) { read('broken.rb') }
  end

  private

  def write(relative_path, content)
    full = File.join(@dir, relative_path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  def read(relative_path)
    reader.call(relative_path)
  end

  def reader(max_size: Ragent::Tools::ReadFile::MAX_SIZE)
    Ragent::Tools::ReadFile.new(@dir, max_size: max_size)
  end
end
