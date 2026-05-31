module Ragent
  DEFAULT_WORKSPACE = ENV.fetch("RAGENT_WORKSPACE", "/workspace")

  def self.run(prompt, workspace: DEFAULT_WORKSPACE)
    puts "Workspace: #{workspace}"
    puts "Received prompt: #{prompt}"
  end
end
