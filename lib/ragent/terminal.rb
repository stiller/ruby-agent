# frozen_string_literal: true

module Ragent
  module Terminal
    CODES = {
      reset: "\e[0m",
      bold: "\e[1m",
      dim: "\e[2m",
      red: "\e[31m",
      green: "\e[32m",
      yellow: "\e[33m",
      cyan: "\e[36m"
    }.freeze

    @color = false
    @debug = false

    class << self
      attr_writer :color, :debug

      def color?
        @color
      end

      def debug?
        @debug
      end

      def debug(msg)
        return unless @debug

        warn fmt("[debug] #{msg}", :dim)
      end

      def fmt(text, *codes)
        return text unless @color

        "#{codes.map { |c| CODES[c] }.join}#{text}#{CODES[:reset]}"
      end

      def tool_line(tool, args_str)
        content = args_str.empty? ? "[#{tool}]" : "[#{tool}] #{args_str}"
        fmt(content, :dim)
      end

      def section(title)
        fmt("── #{title} ──", :yellow)
      end

      def answer_header
        fmt('── Answer ──', :bold, :green)
      end

      def colorize_diff(text)
        return text unless @color

        text.lines.map do |line|
          case line[0]
          when '+' then fmt(line, :green)
          when '-' then fmt(line, :red)
          when '@' then fmt(line, :cyan)
          else line
          end
        end.join
      end
    end
  end
end
