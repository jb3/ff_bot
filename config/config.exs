import Config

config :logger, :console,
  metadata: [:request_id, :installation_id, :repo, :issue, :sender],
  format: "[$level] $message $metadata\n"

if File.exists?("config/#[Mix.env()].exs") do
  import_config "#{Mix.env()}.exs"
end
