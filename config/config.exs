import Config

config :logger, :console,
  metadata: [
    :mfa,
    :registered_name,
    :remote_ip,
    :request_id,
    :installation_id,
    :repo,
    :issue,
    :sender
  ],
  format: "[$level] $metadata | $message\n"

if File.exists?("config/#[Mix.env()].exs") do
  import_config "#{Mix.env()}.exs"
end
