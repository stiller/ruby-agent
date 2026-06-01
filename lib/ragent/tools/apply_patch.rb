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
        content.lines
               .grep_v(GIT_HEADER)
               .map { |l| normalize_path_line(l) }
               .join
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
