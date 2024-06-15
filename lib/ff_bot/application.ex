defmodule FFBot.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: FFBot.Finch},
      {FFBot.Auth.BearerTokenServer, []},
      {FFBot.Auth.InstallationTokenServer, []},
      {Bandit, plug: FFBot.Server.Router, port: Application.get_env(:ff_bot, :service_port)}
    ]

    opts = [strategy: :one_for_one, name: FFBot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
