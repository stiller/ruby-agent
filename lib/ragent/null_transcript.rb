# frozen_string_literal: true

module Ragent
  class NullTranscript
    def run_dir
      nil
    end

    def log_prompt(_content); end

    def log_model_response(_response); end

    def log_tool_result(_tool, _result); end

    def persistent?
      false
    end

    def close; end
  end
end
