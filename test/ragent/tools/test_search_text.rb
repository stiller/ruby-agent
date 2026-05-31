# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../../../lib/ragent'

class TestSearchText < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('ragent-search-test')
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  # --- match fields ---

  def test_returns_correct_path
    write('hello.rb', "puts 'hello world'\n")
    assert_equal 'hello.rb', search('hello').first.path
  end

  def test_returns_correct_line_number
    write('hello.rb', "line one\nhello world\n")
    assert_equal 2, search('hello').first.line_number
  end

  def test_returns_line_content_without_trailing_newline
    write('hello.rb', "puts 'hello world'\n")
    assert_equal "puts 'hello world'", search('hello').first.line
  end

  # --- basic behaviour ---

  def test_returns_empty_array_when_no_matches
    write('hello.rb', "no match here\n")
    assert_equal [], search('xyz_no_match')
  end

  def test_finds_matches_across_multiple_files
    write('a.rb', "needle in a\n")
    write('b.rb', "needle in b\n")
    paths = search('needle').map(&:path)
    assert_includes paths, 'a.rb'
    assert_includes paths, 'b.rb'
  end

  def test_returns_multiple_matches_within_one_file
    write('a.rb', "needle\nneedle\nneedle\n")
    assert_equal 3, search('needle').size
  end

  def test_first_line_match
    write('a.rb', "needle\nother\n")
    assert_equal 1, search('needle').first.line_number
  end

  # --- limit ---

  def test_respects_default_limit
    60.times { |i| write("f#{i}.rb", "needle\n") }
    assert_equal 50, search('needle').size
  end

  def test_custom_limit
    10.times { |i| write("f#{i}.rb", "needle\n") }
    assert_equal 3, searcher(limit: 3).call('needle').size
  end

  def test_returns_all_matches_when_under_limit
    3.times { |i| write("f#{i}.rb", "needle\n") }
    assert_equal 3, search('needle').size
  end

  # --- validation ---

  def test_raises_for_empty_query
    assert_raises(ArgumentError) { search('') }
  end

  # --- binary files ---

  def test_ignores_binary_files
    File.binwrite(File.join(@dir, 'binary.bin'), "needle\x00binary")
    assert_equal [], search('needle')
  end

  def test_searches_non_binary_files_alongside_binary
    File.binwrite(File.join(@dir, 'binary.bin'), "needle\x00binary")
    write('real.rb', "needle\n")
    assert_equal ['real.rb'], search('needle').map(&:path)
  end

  # --- ignored directories ---

  def test_ignores_git_directory
    FileUtils.mkdir_p(File.join(@dir, '.git'))
    write('.git/config', "needle\n")
    assert search('needle').none? { |m| m.path.start_with?('.git') }
  end

  def test_ignores_node_modules
    write('node_modules/pkg/index.js', "needle\n")
    assert search('needle').none? { |m| m.path.start_with?('node_modules') }
  end

  def test_ignores_vendor
    write('vendor/gem/lib.rb', "needle\n")
    assert search('needle').none? { |m| m.path.start_with?('vendor') }
  end

  def test_ignores_tmp
    write('tmp/cache', "needle\n")
    assert search('needle').none? { |m| m.path.start_with?('tmp') }
  end

  def test_ignores_log
    write('log/dev.log', "needle\n")
    assert search('needle').none? { |m| m.path.start_with?('log') }
  end

  def test_ignores_bundle
    write('.bundle/config', "needle\n")
    assert search('needle').none? { |m| m.path.start_with?('.bundle') }
  end

  # --- symlink safety ---

  def test_skips_symlinks_pointing_outside_repo
    outside = Dir.mktmpdir('ragent-outside')
    File.write(File.join(outside, 'secret.rb'), "needle\n")
    File.symlink(File.join(outside, 'secret.rb'), File.join(@dir, 'escape.rb'))
    assert_equal [], search('needle')
  ensure
    FileUtils.rm_rf(outside)
  end

  private

  def write(relative_path, content)
    full = File.join(@dir, relative_path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
  end

  def search(query)
    searcher.call(query)
  end

  def searcher(limit: Ragent::Tools::SearchText::DEFAULT_LIMIT)
    Ragent::Tools::SearchText.new(@dir, limit: limit)
  end
end
