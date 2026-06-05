# frozen_string_literal: true

module Ragent
  class AgentInstructions
    PATHS = ['AGENTS.md', File.join('.ragent', 'AGENTS.md')].freeze

    def initialize(repo_root)
      @repo_root = repo_root
    end

    def load
      PATHS.filter_map do |relative_path|
        path = File.join(@repo_root, relative_path)
        [relative_path, File.read(path)] if File.file?(path)
      end
    end
  end
end
