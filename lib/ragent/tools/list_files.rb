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

      def call(max_depth: nil)
        results = []

        catch(:done) do
          Find.find(@repo_root.to_s) do |path|
            pn = Pathname.new(path)

            if pn.directory?
              handle_directory(pn, results, max_depth)
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

      def handle_directory(pathname, results, max_depth)
        if ignored_dir?(pathname.basename.to_s)
          Find.prune
        elsif max_depth
          handle_bounded_dir(pathname, results, max_depth)
        end
      end

      def handle_bounded_dir(pathname, results, max_depth)
        rel = pathname.relative_path_from(@repo_root)
        unless rel.to_s == '.'
          results << "#{rel}/"
          throw :done if results.size >= @limit
        end
        depth = rel.to_s == '.' ? 0 : rel.each_filename.count
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
