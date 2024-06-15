defmodule FFBot.Auth.InstallationTokenServer do
  @moduledoc """
  A slightly more complex, ETS-backed token store for installation access
  tokens.

  Once of these is issued per installation of the app (i.e. once per org/user),
  as such a new one needs to be issued for every distinct set of repositories
  using the app.

  We check if there is a valid token for the installation ID first, else we
  fetch the bearer token for the app and generate a new one. Then we store
  it with it's expiry in ETS.
  """
  use GenServer

  alias FFBot.{Auth.BearerTokenServer, GitHub}

  require Logger

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    # Create the ETS table we will use to store installation access tokens
    :ets.new(:installation_tokens, [:named_table, :public])

    {:ok, %{}}
  end

  def get_token(install_id) do
    GenServer.call(__MODULE__, {:get_token, install_id})
  end

  defp generate_token(install_id) do
    Logger.info("Generating new token", installation_id: install_id)
    # Create a new token by POSTing to the endpoint using the generated bearer token JWT
    {201, token} =
      GitHub.Request.request(
        :post,
        GitHub.Endpoint.installation_access_token(install_id),
        auth: {:jwt, BearerTokenServer.get_bearer_token()}
      )

    # Convert the expiry date into a native datetime
    {:ok, expires, _} = DateTime.from_iso8601(token["expires_at"])

    # Add the newly generated token to the ETS table
    :ets.insert(:installation_tokens, {install_id, {expires, token["token"]}})

    Logger.debug("New token generated, expires at #{expires}", installation_id: install_id)

    # Return the token
    token["token"]
  end

  @impl true
  def handle_call({:get_token, install_id}, _from, state) do
    # First, lookup for existing tokens
    case :ets.lookup(:installation_tokens, install_id) do
      # If empty, we did not find a token
      [] ->
        # We generate one and return it
        token = generate_token(install_id)

        {:reply, token, state}

      # If we did find a token, we look at the expiry date on it
      [{install_id, {exp, token}}] ->
        # If it expired in the past, create and return a new token
        if exp <= DateTime.utc_now() do
          Logger.info("Token was expired at lookup time, generating new one",
            installation_id: install_id
          )

          token = generate_token(install_id)

          {:reply, token, state}
        else
          # If it did not expire, return the located token
          {:reply, token, state}
        end
    end
  end
end
