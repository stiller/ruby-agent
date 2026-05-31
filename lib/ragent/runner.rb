# frozen_string_literal: true

module Ragent
  def self.run(prompt, workspace: Workspace::DEFAULT_PATH)
    puts "Workspace: #{workspace}"
    puts "Received prompt: #{prompt}"
  end
end
