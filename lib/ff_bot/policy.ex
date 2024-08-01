defmodule FFBot.Policy do
  @moduledoc """
  Policy-related functions for the FFBot application.

  This module parses policy files that define permissions on using the
  application, as well as providing the necessary API methods to validate a
  certain user agains the provided policy file (i.e. checking if they are
  explicitly named, or if not if they are in a named team).
  """
  alias FFBot.GitHub

  require Logger

  defstruct [:teams, :users]

  @doc """
  Fetch the policy file from GitHub for a given owner and repo using the
  provided token.

  If found, it is parsed and returned, otherwise an error (i.e. missing, invalid
  syntax) is returned.
  """
  def get_policy_file(token, owner, repo) do
    # Get the file
    response =
      GitHub.Request.request(
        :get,
        GitHub.Endpoint.policy_file(owner, repo),
        auth: {:token, token}
      )

    # If we found the file, parse it, else return a missing file error.
    case response do
      {200, json} ->
        parse_file(json["content"])

      {status, json} ->
        Logger.error("Retrieved code #{status} with response #{inspect(json)} for policy file at #{owner}/#{repo}")
        {:error, :missing_config}
    end
  end

  defp parse_file(contents) do
    # Decode the content from base64 (maybe with newlines)
    decoded_content = Base.decode64!(contents, ignore: :whitespace)

    # Read and decode the YAML from the file
    case YamlElixir.read_all_from_string(decoded_content) do
      # If it decodes, parse it into the struct
      {:ok, [%{} = config]} -> {:ok, prepare_config(config)}
      # If it does not decode, return a bad YAML error.
      _ -> {:error, :bad_yaml}
    end
  end

  defp prepare_config(config) do
    %__MODULE__{
      teams: config["teams"],
      users: config["users"]
    }
  end

  @doc """
  Test whether a provided username is directly or indirectly in a provided
  policy.

  If the user is immediately named, we short circuit and return true.

  Else, we fetch the members of the specified teams and return if the user
  appears in any of them.
  """
  def test_permission(token, policy, user) do
    is_explicit_user = Enum.member?(policy.users, user)

    if is_explicit_user do
      true
    else
      flattened_team_members = get_team_members(token, policy.teams)

      Enum.member?(flattened_team_members, user)
    end
  end

  defp get_team_members(token, teams) do
    # Start with an empty array as our accumulator
    Enum.reduce(teams, [], fn team, acc ->
      try do
        # Try split the team into the owner and team name (e.g. `python-discord`
        # and `devops`).
        [owner, team] = String.split(team, "/")

        # Request all members from the GitHub API
        members =
          GitHub.Request.request(
            :get,
            GitHub.Endpoint.team_members(owner, team),
            auth: {:token, token}
          )

        case members do
          # If we found the members, add them to the accumulator
          {200, members} ->
            acc ++ Enum.map(members, fn x -> x["login"] end)

          # Any other response, warn about it and continue
          {code, _resp} ->
            Logger.warning("Could not process team: #{team}, code: #{code}")
            acc
        end
      rescue
        # If any error occurred, return the accumulator as is.
        _ -> acc
      end
    end)
  end
end
