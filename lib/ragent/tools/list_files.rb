# frozen_string_literal: true

require 'find'
require 'pathname'

module Ragent
  module Tools
    class ListFiles
      IGNORED_DIRS = %w[.git node_modules vendor tmp log .bundle .ragent].freeze
      DEFAULT_LIMIT = 200

      def initialize(repo_root, limit: DEFAULT_LIMIT, ignored_paths: [])
        @repo_root = Pathname.new(File.realpath(repo_root))
        @limit = limit
        @ignored_paths = ignored_paths
      end

      def call(path: nil, max_depth: nil)
        start_dir = resolve_start_dir(path)
        return ["Error: '#{path}' is not a valid directory path."] unless start_dir

        results = []
        catch(:done) do
          Find.find(start_dir.to_s) do |raw_path|
            pn = Pathname.new(raw_path)

            if pn.directory?
              handle_directory(pn, results, max_depth, start_dir)
              next
            end

            next if pn.symlink? && !safe_symlink?(pn)
            next unless pn.file?

            results << pn.relative_path_from(@repo_root).to_s
            throw :done if results.size >= @limit
          end
        end

        results
      end

      private

      def resolve_start_dir(path)
        return @repo_root if path.nil? || path.to_s.strip.empty?

        candidate = @repo_root.join(path)
        real = Pathname.new(File.realpath(candidate.to_s))
        return nil unless real.to_s.start_with?(@repo_root.to_s)
        return nil unless real.directory?

        real
      rescue Errno::ENOENT
        nil
      end

      def handle_directory(pathname, results, max_depth, start_dir)
        if ignored_dir?(pathname.basename.to_s)
          Find.prune
        elsif max_depth
          handle_bounded_dir(pathname, results, max_depth, start_dir)
        end
      end

      def handle_bounded_dir(pathname, results, max_depth, start_dir)
        unless pathname == start_dir
          results << "#{pathname.relative_path_from(@repo_root)}/"
          throw :done if results.size >= @limit
        end
        depth = pathname == start_dir ? 0 : pathname.relative_path_from(start_dir).each_filename.count
        Find.prune if depth >= max_depth
      end

      def ignored_dir?(name)
        IGNORED_DIRS.include?(name) || @ignored_paths.include?(name)
      end

      def safe_symlink?(pathname)
        real = Pathname.new(File.realpath(pathname.to_s))
        real.to_s.start_with?("#{@repo_root}/")
      rescue Errno::ENOENT
        false
      end
    end
  end
end
