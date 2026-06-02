# frozen_string_literal: true

module Ragent
  class WorkspaceError < StandardError; end

  module Workspace
    DEFAULT_PATH = ENV.fetch('RAGENT_WORKSPACE', '/workspace')
    GITIGNORE_ENTRY = '.ragent/'

    def self.validate!(path)
      raise WorkspaceError, "repo root '#{path}' does not exist or is not a directory" unless Dir.exist?(path)

      path
    end

    def self.ensure_ragent_ignored!(path)
      gitignore = File.join(path, '.gitignore')
      existing = File.exist?(gitignore) ? File.read(gitignore) : ''
      return if existing.lines.any? { |l| [GITIGNORE_ENTRY, '.ragent'].include?(l.chomp) }

      File.open(gitignore, 'a') { |f| f.puts GITIGNORE_ENTRY }
    end
  end
end
