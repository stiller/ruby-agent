# frozen_string_literal: true

require 'fileutils'

module Ragent
  class WorkspaceError < StandardError; end

  module Workspace
    DEFAULT_PATH = ENV.fetch('RAGENT_WORKSPACE', '/workspace')
    GITIGNORE_ENTRY = '.ragent/'

    def self.validate!(path)
      raise WorkspaceError, "repo root '#{path}' does not exist or is not a directory" unless Dir.exist?(path)

      path
    end

    def self.ragent_ignored?(path)
      gitignore = File.join(path, '.gitignore')
      return false unless File.exist?(gitignore)

      File.read(gitignore).lines.any? { |l| [GITIGNORE_ENTRY, '.ragent'].include?(l.chomp) }
    rescue Errno::EACCES, Errno::EPERM
      false
    end

    def self.ensure_ragent_ignored!(path)
      gitignore = File.join(path, '.gitignore')
      existing = File.exist?(gitignore) ? File.read(gitignore) : ''
      return if existing.lines.any? { |l| [GITIGNORE_ENTRY, '.ragent'].include?(l.chomp) }

      File.open(gitignore, 'a') { |f| f.puts GITIGNORE_ENTRY }
    rescue Errno::EROFS, Errno::EACCES, Errno::EPERM
      nil
    end

    def self.resolve_artifact_dir(workspace, artifact_dir: nil, allow_external: false)
      if artifact_dir
        resolved = File.expand_path(artifact_dir)
        workspace_abs = File.expand_path(workspace)
        inside = resolved.start_with?("#{workspace_abs}#{File::SEPARATOR}") || resolved == workspace_abs
        unless inside || allow_external
          raise WorkspaceError,
                "'#{artifact_dir}' is outside the repository; pass --allow-external-artifacts to use it"
        end
        FileUtils.mkdir_p(resolved)
        resolved
      else
        path = File.join(workspace, '.ragent', 'runs')
        FileUtils.mkdir_p(path)
        return nil unless File.writable?(path)

        path
      end
    rescue Errno::EROFS, Errno::EACCES, Errno::EPERM => e
      raise WorkspaceError, "cannot write to artifact dir: #{e.message}" if artifact_dir

      nil
    end
  end
end
