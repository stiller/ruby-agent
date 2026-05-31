# frozen_string_literal: true

require 'find'
require 'pathname'

module Ragent
  module Tools
    class ListFiles
      IGNORED_DIRS = %w[.git node_modules vendor tmp log .bundle].freeze
      DEFAULT_LIMIT = 200

      def initialize(repo_root, limit: DEFAULT_LIMIT)
        @repo_root = Pathname.new(File.realpath(repo_root))
        @limit = limit
      end

      def call
        results = []

        catch(:done) do
          Find.find(@repo_root.to_s) do |path|
            pn = Pathname.new(path)

            if pn.directory?
              Find.prune if IGNORED_DIRS.include?(pn.basename.to_s)
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

      def safe_symlink?(pn)
        real = Pathname.new(File.realpath(pn.to_s))
        real.to_s.start_with?("#{@repo_root}/")
      rescue Errno::ENOENT
        false
      end
    end
  end
end
