defmodule FFBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :ff_bot,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {FFBot.Application, []}
    ]
  end

  defp deps do
    [
      {:bandit, "~> 1.0"},
      {:joken, "~> 2.5"},
      {:finch, "~> 0.18.0"},
      {:jason, "~> 1.4"},
      {:yaml_elixir, "~> 2.9"},
      {:temp, "~> 0.4"},
      {:git_cli, "~> 0.3"},
      {:remote_ip, "~> 1.2"},
      {:credo, "~> 1.7", only: [:dev]}
    ]
  end
end
