# frozen_string_literal: true

module Ragent
  class WorkspaceError < StandardError; end

  module Workspace
    DEFAULT_PATH = ENV.fetch('RAGENT_WORKSPACE', '/workspace')

    def self.validate!(path)
      raise WorkspaceError, "repo root '#{path}' does not exist or is not a directory" unless Dir.exist?(path)

      path
    end
  end
end
