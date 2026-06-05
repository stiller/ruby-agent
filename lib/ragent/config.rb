# frozen_string_literal: true

require 'yaml'

module Ragent
  class Config
    FILENAME = '.ragent.yml'

    def initialize(repo_root)
      @repo_root = repo_root
    end

    def allowed_commands
      data.fetch('allowed_commands', [])
    end

    private

    def data
      @data ||= load_data
    end

    def load_data
      path = File.join(@repo_root, FILENAME)
      return {} unless File.exist?(path)

      YAML.safe_load_file(path) || {}
    end
  end
end
