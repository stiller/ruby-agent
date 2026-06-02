# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'open3'

module Ragent
  class Checkpoint
    def initialize(repo_root, run_dir:)
      @repo_root = repo_root
      @run_dir = run_dir
    end

    def git_repo?
      return @git_repo unless @git_repo.nil?

      _, st = Open3.capture2e('git', '-C', @repo_root, 'rev-parse', '--git-dir')
      @git_repo = st.success?
    end

    def save(patch_file)
      return unless git_repo?

      data = {
        branch: git_branch,
        status: git_status,
        diff: git_diff,
        patch: File.read(patch_file)
      }
      FileUtils.mkdir_p(@run_dir)
      File.write(checkpoint_path, JSON.generate(data))
    end

    private

    def git_branch
      out, = Open3.capture2e('git', '-C', @repo_root, 'rev-parse', '--abbrev-ref', 'HEAD')
      out.strip
    end

    def git_status
      out, = Open3.capture2e('git', '-C', @repo_root, 'status', '--short')
      out
    end

    def git_diff
      out, = Open3.capture2e('git', '-C', @repo_root, 'diff')
      out
    end

    def checkpoint_path
      slug = Time.now.strftime('%Y%m%d-%H%M%S')
      File.join(@run_dir, "checkpoint-#{slug}.json")
    end
  end
end
