# frozen_string_literal: true

require 'json'
require 'tempfile'

module Ragent
  class Rollback
    class CheckpointMissing < StandardError; end

    def initialize(repo_root)
      @repo_root = repo_root
    end

    def call(run_dir, input: $stdin, output: $stderr)
      data = load_checkpoint(run_dir)

      output.puts data['patch']
      output.print 'Roll back this patch? [y/N] '
      return 'Rollback cancelled.' unless input.gets&.strip&.downcase == 'y'

      result = attempt_reverse(data['patch'])
      if result.is_a?(Tools::ApplyPatch::Error)
        "#{result}\n\n#{manual_instructions(data)}"
      else
        "Rolled back successfully. Modified: #{result.modified_files.join(', ')}."
      end
    end

    private

    def load_checkpoint(run_dir)
      file = Dir.glob(File.join(run_dir, 'checkpoint-*.json')).first
      raise CheckpointMissing, "No checkpoint found in #{run_dir}" unless file

      JSON.parse(File.read(file))
    end

    def attempt_reverse(patch_content)
      Tempfile.open(['rollback', '.diff']) do |tmp|
        tmp.write(patch_content)
        tmp.flush
        Tools::ApplyPatch.new(@repo_root).reverse(tmp.path)
      end
    end

    def manual_instructions(data)
      status = data['status'].to_s.strip
      <<~TEXT.strip
        Automatic rollback failed. To reverse the patch manually:

          patch -R -p1 < patch.diff

        Or restore committed files directly:

          git checkout -- <file>

        State when the patch was applied:
          Branch: #{data['branch']}
          Status: #{status.empty? ? '(clean)' : "\n#{status.gsub(/^/, '            ')}"}
      TEXT
    end
  end
end
