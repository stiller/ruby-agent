# frozen_string_literal: true

require 'open3'

module Ragent
  module Tools
    class ApplyPatch
      Result = Struct.new(:patch_file, :modified_files, keyword_init: true) do
        def to_s
          "Patch applied. Modified: #{modified_files.join(', ')}."
        end
      end

      Error = Struct.new(:message, keyword_init: true) do
        def to_s
          "Failed to apply patch: #{message}"
        end
      end

      # Matches git-extended header lines that contain fabricated blob SHAs.
      GIT_HEADER = /\A(diff --git |index [0-9a-f])/
      HUNK_HEADER = /\A@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/

      def initialize(repo_root)
        @repo_root = repo_root
      end

      def call(patch_file)
        cleaned = clean(File.read(patch_file))
        out, status = Open3.capture2e(
          'git', '-C', @repo_root, 'apply', '-C3', '-',
          stdin_data: cleaned
        )
        return Error.new(message: out.strip) unless status.success?

        Result.new(patch_file: patch_file, modified_files: modified_files(cleaned))
      end

      def check(patch_file)
        cleaned = clean(File.read(patch_file))
        out, status = Open3.capture2e(
          'git', '-C', @repo_root, 'apply', '--check', '-C3', '-',
          stdin_data: cleaned
        )
        status.success? ? nil : Error.new(message: out.strip)
      end

      private

      def clean(content)
        normalized = content.lines
                            .grep_v(GIT_HEADER)
                            .map { |l| normalize_path_line(l) }
                            .join
        fix_hunk_headers(normalized)
      end

      def fix_hunk_headers(content)
        content.lines
               .slice_before { |l| l.match?(HUNK_HEADER) || l.start_with?('--- ', '+++ ') }
               .flat_map { |chunk| rewrite_hunk_chunk(chunk) }
               .join
      end

      def rewrite_hunk_chunk(chunk)
        m = HUNK_HEADER.match(chunk.first)
        return chunk unless m

        hunk = chunk.drop(1)
        old_count = hunk.count { |l| l.start_with?(' ', '-') }
        new_count = hunk.count { |l| l.start_with?(' ', '+') }
        ["@@ -#{m[1]},#{old_count} +#{m[2]},#{new_count} @@\n", *hunk]
      end

      def normalize_path_line(line)
        case line
        when %r{\A--- (?!a/|/dev/)}
          "--- a/#{line[4..]}"
        when %r{\A\+\+\+ (?!b/|/dev/)}
          "+++ b/#{line[4..]}"
        else
          line
        end
      end

      def modified_files(content)
        content.lines
               .select { |l| l.start_with?('+++ ') }
               .map { |l| l[4..].chomp.sub(%r{\Ab/}, '') }
               .reject { |p| p == File::NULL }
      end
    end
  end
end
