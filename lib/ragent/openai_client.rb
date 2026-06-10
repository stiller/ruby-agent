# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

module Ragent
  class APIError < StandardError; end

  class OpenAIClient < ModelClient
    DEFAULT_BASE_URL = 'https://api.openai.com'
    DEFAULT_MODEL = 'gpt-5.5'
    MAX_RETRIES = 3

    def initialize(
      tool_definitions: [],
      api_key: ENV.fetch('OPENAI_API_KEY', nil),
      base_url: ENV.fetch('OPENAI_BASE_URL', DEFAULT_BASE_URL),
      model: ENV.fetch('RAGENT_MODEL', DEFAULT_MODEL)
    )
      super()
      raise ArgumentError, 'OPENAI_API_KEY is not set' if api_key.to_s.empty?

      @api_key = api_key
      @base_url = base_url.chomp('/')
      @model = model
      @tool_definitions = tool_definitions
    end

    def call(messages)
      if Terminal.debug?
        chars = messages.sum { |m| m[:content].to_s.length }
        Terminal.debug("request model=#{@model} messages=#{messages.size} content=~#{chars}chars")
      end
      data = post('/v1/chat/completions', build_body(messages))
      parse_response(data)
    end

    private

    def build_body(messages)
      body = { model: @model, messages: messages.map { |m| serialize_message(m) } }
      body[:tools] = @tool_definitions.map(&:to_openai_schema) if @tool_definitions.any?
      body
    end

    def serialize_message(msg)
      case msg[:role]
      when 'system'    then { role: 'system', content: msg[:content] }
      when 'user'      then { role: 'user', content: msg[:content] }
      when 'assistant' then serialize_assistant(msg)
      when 'tool'      then { role: 'tool', tool_call_id: msg[:tool_call_id].to_s, content: msg[:content].to_s }
      end
    end

    def serialize_assistant(msg)
      return { role: 'assistant', content: msg[:content].to_s } unless msg[:tool_calls]

      tc = msg[:tool_calls].first
      {
        role: 'assistant', content: nil,
        tool_calls: [{
          id: tc[:id].to_s, type: 'function',
          function: { name: tc[:name], arguments: JSON.generate(tc[:args] || {}) }
        }]
      }
    end

    def post(path, body)
      retries = 0
      loop do
        uri = URI("#{@base_url}#{path}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.open_timeout = 10
        http.read_timeout = 120

        req = Net::HTTP::Post.new(uri.path)
        req['Authorization'] = "Bearer #{@api_key}"
        req['Content-Type'] = 'application/json'
        req.body = JSON.generate(body)

        resp = http.request(req)

        if resp.code == '429' && retries < MAX_RETRIES
          retries += 1
          wait = parse_retry_after(resp)
          warn Terminal.fmt("Rate limit; waiting #{wait}s (retry #{retries}/#{MAX_RETRIES})…", :yellow)
          sleep(wait)
          next
        end

        raise APIError, "HTTP #{resp.code}: #{resp.body}" unless resp.is_a?(Net::HTTPSuccess)

        return JSON.parse(resp.body)
      end
    end

    def parse_retry_after(resp)
      header = resp['Retry-After']
      return header.to_f.ceil if header&.to_f&.positive?

      if (m = resp.body.to_s.match(/try again in ([\d.]+)s/))
        m[1].to_f.ceil + 1
      else
        10
      end
    end

    def parse_response(data)
      message = data.dig('choices', 0, 'message')
      raise APIError, "Unexpected API response: #{data.inspect}" unless message

      tool_calls = message['tool_calls']
      return Response::Final.new(content: message['content']) if tool_calls.nil? || tool_calls.empty?

      tc = tool_calls.first
      Response::ToolCall.new(
        tool: tc.dig('function', 'name'),
        args: JSON.parse(tc.dig('function', 'arguments')),
        id: tc['id']
      )
    end
  end
end
