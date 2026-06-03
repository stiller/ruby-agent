# frozen_string_literal: true

module Ragent
  module Tools
    class ProposeCommand
      Result = Struct.new(:command, :reason, keyword_init: true) do
        def to_s
          "Command proposed (not executed): #{command}\nReason: #{reason}"
        end
      end

      Error = Struct.new(:reason, keyword_init: true) do
        def to_s
          "Command rejected: #{reason}"
        end
      end

      DANGEROUS_PATTERNS = [
        [%r{\brm\s+-[a-z]*r[a-z]*f[a-z]*\s+/}i, 'rm -rf targeting /'],
        [%r{\brm\s+-[a-z]*f[a-z]*r[a-z]*\s+/}i, 'rm -rf targeting /'],
        [/\bshutdown\b/i,                         'shutdown'],
        [/\breboot\b/i,                           'reboot'],
        [/\bmkfs\b/i,                             'mkfs'],
        [/\bdd\b/,                                'dd'],
        [/\bcurl\b.+\|.+\bsh\b/,                'curl piped to shell'],
        [/\bwget\b.+\|.+\bsh\b/,                'wget piped to shell'],
        [%r{~/\.ssh},                             '~/.ssh'],
        [%r{/etc\b},                              '/etc']
      ].freeze

      def call(command, reason)
        hit = DANGEROUS_PATTERNS.find { |pattern, _| pattern.match?(command) }
        return Error.new(reason: "command touches #{hit[1]}") if hit

        Result.new(command: command, reason: reason)
      end
    end
  end
end
