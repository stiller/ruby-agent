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
