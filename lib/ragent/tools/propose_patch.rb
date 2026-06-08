# frozen_string_literal: true

require 'pathname'
require 'fileutils'

module Ragent
  module Tools
    class ProposePatch
      Result = Struct.new(:patch_file, keyword_init: true) do
        def to_s
          "Patch proposed and saved to #{patch_file}. NOT applied."
        end
      end

      Error = Struct.new(:reason, keyword_init: true) do
        def to_s
          "Patch rejected: #{reason}"
        end
      end

      IGNORED_DIRS = ListFiles::IGNORED_DIRS

      def initialize(repo_root, run_dir:)
        @repo_root = File.realpath(repo_root)
        @run_dir = run_dir
      end

      def call(diff)
        err = validate_headers(diff)
        return err if err

        paths = extract_paths(diff)
        return Error.new(reason: 'no file paths found in diff') if paths.empty?

        paths.each do |path|
          err = validate_path(path)
          return err if err
        end

        save_patch(diff)
      end

      private

      def extract_paths(diff)
        paths = []
        diff.to_s.each_line do |line|
          next unless line.start_with?('--- ', '+++ ')

          path = line[4..].chomp
          next if path == File::NULL

          paths << path.sub(%r{\A[ab]/}, '')
        end
        paths.uniq
      end

      def validate_headers(diff)
        minus, plus = extract_header_paths(diff)
        return nil unless minus && plus

        src = minus == File::NULL ? nil : minus
        dst = plus == File::NULL ? nil : plus
        return nil if src.nil? || dst.nil? || src == dst

        Error.new(reason: "source '#{minus}' and target '#{plus}' filenames differ; " \
                          "to create a new file use '--- /dev/null', " \
                          'to edit a file use the same filename in both --- and +++ lines')
      end

      def extract_header_paths(diff)
        minus = plus = nil
        diff.to_s.each_line do |line|
          if line.start_with?('--- ')
            minus = line[4..].chomp.sub(%r{\A[ab]/}, '')
          elsif line.start_with?('+++ ')
            plus = line[4..].chomp.sub(%r{\A[ab]/}, '')
          end
        end
        [minus, plus]
      end

      def validate_path(path)
        components = Pathname.new(path).each_filename.to_a
        hit = components.find { |c| IGNORED_DIRS.include?(c) }
        return Error.new(reason: "path '#{path}' touches ignored directory '#{hit}'") if hit

        full = File.expand_path(path, @repo_root)
        unless full.start_with?("#{@repo_root}/")
          return Error.new(reason: "path '#{path}' is outside the repository root")
        end

        nil
      end

      def save_patch(diff)
        patches_dir = File.join(@run_dir, 'patches')
        FileUtils.mkdir_p(patches_dir)
        slug = Time.now.strftime('%Y%m%d-%H%M%S')
        patch_file = File.join(patches_dir, "patch-#{slug}.diff")
        File.write(patch_file, diff)
        Result.new(patch_file: patch_file)
      end
    end
  end
end
