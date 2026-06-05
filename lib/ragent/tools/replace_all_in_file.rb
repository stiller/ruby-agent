# frozen_string_literal: true

require 'pathname'
require 'fileutils'
require_relative '../unified_diff'

module Ragent
  module Tools
    class ReplaceAllInFile
      Result = Struct.new(:path, :patch_file, :replacement_count, keyword_init: true) do
        def to_s
          "Replaced #{replacement_count} occurrence(s) in #{path}."
        end
      end

      Error = Struct.new(:message, keyword_init: true) do
        def to_s
          message
        end
      end

      def initialize(repo_root, run_dir:)
        @repo_root = File.realpath(repo_root)
        @run_dir = run_dir
      end

      def call(path, old_text, new_text)
        err = validate_path(path)
        return err if err

        full_path = File.join(@repo_root, path.to_s)
        return Error.new(message: "File not found: #{path}") unless File.file?(full_path)

        content = File.read(full_path)
        pattern = Regexp.new(Regexp.escape(old_text.to_s))
        count = content.scan(pattern).length
        return Error.new(message: "old_text not found in #{path}") if count.zero?

        new_content = content.gsub(pattern) { new_text.to_s }
        patch_file = generate_diff(path, content, new_content)
        Result.new(path: path, patch_file: patch_file, replacement_count: count)
      end

      private

      def validate_path(path)
        return Error.new(message: 'path must be relative') if Pathname.new(path.to_s).absolute?

        full = File.expand_path(path.to_s, @repo_root)
        unless full.start_with?("#{@repo_root}/")
          return Error.new(message: "path '#{path}' is outside the repository root")
        end

        nil
      end

      def generate_diff(path, old_content, new_content)
        patches_dir = File.join(@run_dir, 'patches')
        FileUtils.mkdir_p(patches_dir)
        n = Dir[File.join(patches_dir, 'replace_all_*.patch')].size
        patch_file = File.join(patches_dir, "replace_all_#{n}.patch")
        File.write(patch_file, compute_diff(path, old_content, new_content))
        patch_file
      end

      def compute_diff(path, old_content, new_content)
        UnifiedDiff.compute(path, old_content, new_content)
      end
    end
  end
end
