defmodule FFBot.Auth.BearerTokenServer do
  @moduledoc """
  This small GenServer generates and keeps hold of a currently valid signed JWT
  that is used to issue access tokens for app installations.

  The tokens generated are only recreated if the expiry of 10 minutes has been
  reached, after which a new token is created and placed into the server state.
  """
  use GenServer

  alias FFBot.Auth.BearerToken

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    {:ok,
     %{
       bearer_token: "",
       exp: -1
     }}
  end

  def get_bearer_token do
    GenServer.call(__MODULE__, :get_bearer_token)
  end

  @impl true
  def handle_call(:get_bearer_token, _from, state) do
    # Unix time in seconds
    time_now = System.os_time() / 1_000_000_000

    # Test for token expiry
    if state.exp - 10 <= time_now do
      # Create an issuing time in seconds
      issue_time = Integer.floor_div(System.os_time(), 1_000_000_000)

      # Create the JWT Body
      bearer_token_data = %{
        "iat" => issue_time - 60,
        "exp" => issue_time + 10 * 60,
        "iss" => Application.get_env(:ff_bot, :github_client_id)
      }

      # Create a new signer using the github client secret
      signer =
        Joken.Signer.create("RS256", %{
          "pem" => Application.get_env(:ff_bot, :github_client_secret)
        })

      # Sign the JWT
      {:ok, bearer_token, _data} =
        BearerToken.generate_and_sign(bearer_token_data, signer)

      # Reply with the new token and update the token in state with the new expiry time
      {:reply, bearer_token, %{state | bearer_token: bearer_token, exp: issue_time + 10 * 60}}
    else
      # If the token was valid, just return it.
      {:reply, state.bearer_token, state}
    end
  end
end
