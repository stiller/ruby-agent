# frozen_string_literal: true

require 'yaml'

module Ragent
  class ConfigError < StandardError; end

  class Config
    FILENAME = '.ragent.yml'
    VALID_APPROVAL_MODES = %w[ask auto].freeze

    def initialize(repo_root)
      @repo_root = repo_root
      validate!
    end

    def allowed_commands   = data.fetch('allowed_commands', [])
    def ignored_paths      = data.fetch('ignored_paths', [])
    def max_file_size      = data.fetch('max_file_size', nil)
    def max_search_results = data.fetch('max_search_results', nil)
    def approval_mode      = data.fetch('approval_mode', 'ask')

    private

    def data
      @data ||= load_data
    end

    def load_data
      path = File.join(@repo_root, FILENAME)
      return {} unless File.exist?(path)

      YAML.safe_load_file(path) || {}
    end

    def validate!
      validate_string_list!('allowed_commands')
      validate_string_list!('ignored_paths')
      validate_positive_integer!('max_file_size')
      validate_positive_integer!('max_search_results')
      validate_approval_mode!
    end

    def validate_string_list!(key)
      val = data[key]
      return if val.nil?
      raise ConfigError, "#{key} must be a list of strings" unless val.is_a?(Array) && val.all?(String)
    end

    def validate_positive_integer!(key)
      val = data[key]
      return if val.nil?
      raise ConfigError, "#{key} must be a positive integer" unless val.is_a?(Integer) && val.positive?
    end

    def validate_approval_mode!
      mode = data['approval_mode']
      return if mode.nil? || VALID_APPROVAL_MODES.include?(mode)

      raise ConfigError, "approval_mode must be one of: #{VALID_APPROVAL_MODES.join(', ')}"
    end
  end
end
