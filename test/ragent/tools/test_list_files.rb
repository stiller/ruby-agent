require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../../../lib/ragent"

class TestListFiles < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("ragent-list-test")
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  # --- basic listing ---

  def test_returns_relative_paths
    FileUtils.touch(File.join(@dir, "hello.rb"))
    assert_includes list, "hello.rb"
  end

  def test_lists_nested_files
    FileUtils.mkdir_p(File.join(@dir, "lib/ragent"))
    FileUtils.touch(File.join(@dir, "lib/ragent/runner.rb"))
    assert_includes list, "lib/ragent/runner.rb"
  end

  def test_empty_directory_returns_empty_array
    assert_equal [], list
  end

  # --- ignored directories ---

  def test_ignores_git
    touch_inside(".git", "HEAD")
    assert list.none? { |f| f.start_with?(".git") }
  end

  def test_ignores_node_modules
    touch_inside("node_modules/lodash", "index.js")
    assert list.none? { |f| f.start_with?("node_modules") }
  end

  def test_ignores_vendor
    touch_inside("vendor/bundle", "gem.rb")
    assert list.none? { |f| f.start_with?("vendor") }
  end

  def test_ignores_tmp
    touch_inside("tmp", "cache.txt")
    assert list.none? { |f| f.start_with?("tmp") }
  end

  def test_ignores_log
    touch_inside("log", "development.log")
    assert list.none? { |f| f.start_with?("log") }
  end

  def test_ignores_bundle
    touch_inside(".bundle", "config")
    assert list.none? { |f| f.start_with?(".bundle") }
  end

  def test_does_not_ignore_files_that_share_a_prefix_with_ignored_dirs
    FileUtils.touch(File.join(@dir, "vendor.rb"))
    assert_includes list, "vendor.rb"
  end

  # --- limit ---

  def test_respects_default_limit
    205.times { |i| FileUtils.touch(File.join(@dir, "f#{i}.rb")) }
    assert_equal 200, list.size
  end

  def test_custom_limit
    10.times { |i| FileUtils.touch(File.join(@dir, "f#{i}.rb")) }
    assert_equal 3, list(limit: 3).size
  end

  def test_returns_all_files_when_under_limit
    3.times { |i| FileUtils.touch(File.join(@dir, "f#{i}.rb")) }
    assert_equal 3, list.size
  end

  # --- symlink safety ---

  def test_skips_symlinks_pointing_outside_repo
    outside = Dir.mktmpdir("ragent-outside")
    secret = File.join(outside, "secret.txt")
    File.write(secret, "secret")
    File.symlink(secret, File.join(@dir, "escape.txt"))

    assert list.none? { |f| f.include?("escape") || f.include?("secret") }
  ensure
    FileUtils.rm_rf(outside)
  end

  def test_includes_symlinks_pointing_inside_repo
    target = File.join(@dir, "real.rb")
    File.write(target, "")
    File.symlink(target, File.join(@dir, "link.rb"))

    result = list
    assert_includes result, "real.rb"
    assert_includes result, "link.rb"
  end

  def test_skips_broken_symlinks
    File.symlink("/nonexistent/path", File.join(@dir, "broken.txt"))
    assert list.none? { |f| f.include?("broken") }
  end

  private

  def list(limit: Ragent::Tools::ListFiles::DEFAULT_LIMIT)
    Ragent::Tools::ListFiles.new(@dir, limit: limit).call
  end

  def touch_inside(subdir, filename)
    path = File.join(@dir, subdir)
    FileUtils.mkdir_p(path)
    FileUtils.touch(File.join(path, filename))
  end
end
