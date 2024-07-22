import Config

config :ff_bot,
  github_webhook_secret: System.fetch_env!("GITHUB_WEBHOOK_SECRET"),
  github_client_id: System.fetch_env!("GITHUB_CLIENT_ID"),
  github_client_secret: System.fetch_env!("GITHUB_CLIENT_SECRET") |> String.replace("\\n", "\n"),
  policy_file: System.get_env("FF_POLICY_FILE", ".github/ff-bot.yml"),
  service_port: System.get_env("FF_LISTEN_PORT", "4000") |> String.to_integer(),
  reagan_supporter?: System.get_env("FF_REAGAN_SUPPORTER")
