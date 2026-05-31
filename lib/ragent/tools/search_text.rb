# frozen_string_literal: true

require 'find'
require 'pathname'
require_relative 'list_files'

module Ragent
  module Tools
    class SearchText
      DEFAULT_LIMIT = 50
      BINARY_CHECK_BYTES = 8192

      Match = Struct.new(:path, :line_number, :line, keyword_init: true)

      def initialize(repo_root, limit: DEFAULT_LIMIT)
        @repo_root = Pathname.new(File.realpath(repo_root))
        @limit = limit
      end

      def call(query)
        raise ArgumentError, 'query must not be empty' if query.empty?

        results = []

        catch(:done) do
          each_file do |relative_path, full_path|
            next if binary?(full_path)

            search_file(full_path, relative_path, query, results)
          end
        end

        results
      end

      private

      def each_file
        Find.find(@repo_root.to_s) do |path|
          pn = Pathname.new(path)

          if pn.directory?
            Find.prune if ListFiles::IGNORED_DIRS.include?(pn.basename.to_s)
            next
          end

          next if pn.symlink? && !safe_symlink?(pn)
          next unless pn.file?

          yield pn.relative_path_from(@repo_root).to_s, path
        end
      end

      def search_file(full_path, relative_path, query, results)
        File.open(full_path, encoding: 'utf-8:utf-8', invalid: :replace, undef: :replace) do |f|
          f.each_line.with_index(1) do |line, line_number|
            next unless line.include?(query)

            results << Match.new(path: relative_path, line_number: line_number, line: line.chomp)
            throw :done if results.size >= @limit
          end
        end
      rescue Errno::EACCES, Errno::ENOENT
        nil
      end

      def binary?(path)
        File.open(path, 'rb') { |f| f.read(BINARY_CHECK_BYTES)&.include?("\x00") }
      rescue Errno::EACCES, Errno::ENOENT
        true
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
