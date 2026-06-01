# frozen_string_literal: true

require 'pathname'

module Ragent
  class FileTooLargeError < StandardError; end

  module Tools
    class ReadFile
      MAX_SIZE = 100 * 1024 # 100 KB

      Result = Struct.new(:path, :content, :byte_size, :truncated, keyword_init: true)

      def initialize(repo_root, max_size: MAX_SIZE)
        @repo_root = Pathname.new(File.realpath(repo_root))
        @max_size = max_size
      end

      def call(relative_path)
        raise ArgumentError, "path must be relative, got: #{relative_path}" if Pathname.new(relative_path).absolute?
        raise ArgumentError, "path must not contain '..'" if traversal?(relative_path)

        full_path = @repo_root.join(relative_path)

        raise Errno::ENOENT, relative_path unless full_path.exist?

        real = Pathname.new(File.realpath(full_path.to_s))
        unless real.to_s.start_with?("#{@repo_root}/")
          raise ArgumentError, "path '#{relative_path}' escapes the repo root"
        end

        byte_size = real.size
        if byte_size > @max_size
          raise FileTooLargeError,
                "'#{relative_path}' is #{byte_size} bytes, limit is #{@max_size} bytes"
        end

        Result.new(path: relative_path, content: real.read, byte_size: byte_size, truncated: false)
      end

      private

      def traversal?(path)
        Pathname.new(path).each_filename.any? { |part| part == '..' }
      end
    end
  end
end
