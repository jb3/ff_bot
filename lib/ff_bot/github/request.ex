defmodule FFBot.GitHub.Request do
  @moduledoc """
  Convenience module for sending API requests off to the GitHub API.
  """
  alias FFBot.GitHub.Endpoint

  require Logger

  # Helper function to build a specified auth header into the valid
  # format to send to the API
  defp build_auth({:jwt, jwt}) do
    "Bearer #{jwt}"
  end

  defp build_auth({:token, token}) do
    "Token #{token}"
  end

  @doc """
  Perform a request to the GitHub API, given a method, endpoint and additionally
  authentication and data (encoded as JSON). Returns status code and response body.
  """
  def request(method, endpoint, opts \\ []) do
    # If we are passed a body, encode it to JSON
    body =
      case opts[:data] do
        nil -> nil
        other -> List.to_string(:json.encode(other))
      end

    Logger.debug("Making #{method} request to #{endpoint}")

    # Build and send the request with the provided parameters,
    # filling in auth if needed
    request =
      Finch.build(
        method,
        Endpoint.base() <> endpoint,
        [
          {"Authorization", build_auth(opts[:auth])},
          {"Accept", "application/vnd.github+json"},
          {"Content-Type", "application/json"}
        ],
        body
      )
      |> Finch.request(FFBot.Finch)

    # Based on the response, either return the status and the body or
    # the exception if a request error takes place
    case request do
      {:ok, resp} -> {resp.status, :json.decode(resp.body)}
      {:error, _exception} -> request
    end
  end

  @doc """
  Helper utility to post a comment with given severity onto the provided issue number on
  the specified repository. Useful for responding to commands.
  """
  def comment(token, owner, repo, issue_num, level, body) do
    emoji =
      case level do
        :info -> ":information_source:"
        :warning -> ":warning:"
        :error -> ":x:"
        :success -> ":white_check_mark:"
      end

    request(
      :post,
      Endpoint.issue_comments(owner, repo, issue_num),
      auth: {:token, token},
      data: %{
        "body" => "#{emoji} #{body}"
      }
    )
  end
end
