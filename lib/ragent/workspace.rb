# frozen_string_literal: true

require 'fileutils'

module Ragent
  class WorkspaceError < StandardError; end

  module Workspace
    DEFAULT_PATH = ENV.fetch('RAGENT_WORKSPACE', '/workspace')
    GITIGNORE_ENTRY = '.ragent/'
    READONLY_RUNS_DIR = '/tmp/ragent-runs'

    def self.validate!(path)
      raise WorkspaceError, "repo root '#{path}' does not exist or is not a directory" unless Dir.exist?(path)

      path
    end

    def self.ensure_ragent_ignored!(path)
      gitignore = File.join(path, '.gitignore')
      existing = File.exist?(gitignore) ? File.read(gitignore) : ''
      return if existing.lines.any? { |l| [GITIGNORE_ENTRY, '.ragent'].include?(l.chomp) }

      File.open(gitignore, 'a') { |f| f.puts GITIGNORE_ENTRY }
    rescue Errno::EROFS, Errno::EACCES, Errno::EPERM
      nil
    end

    def self.resolve_runs_dir(workspace)
      path = File.join(workspace, '.ragent', 'runs')
      FileUtils.mkdir_p(path)
      path
    rescue Errno::EROFS, Errno::EACCES, Errno::EPERM
      warn "Workspace is read-only; run artifacts stored at #{READONLY_RUNS_DIR} (ephemeral)"
      READONLY_RUNS_DIR
    end
  end
end
