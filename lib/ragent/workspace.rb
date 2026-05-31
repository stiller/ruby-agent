module Ragent
  class WorkspaceError < StandardError; end

  module Workspace
    DEFAULT_PATH = ENV.fetch("RAGENT_WORKSPACE", "/workspace")

    def self.validate!(path)
      unless Dir.exist?(path)
        raise WorkspaceError, "repo root '#{path}' does not exist or is not a directory"
      end
      path
    end
  end
end
