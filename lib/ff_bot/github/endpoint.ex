defmodule FFBot.GitHub.Endpoint do
  @moduledoc """
  Endpoint collection for all GitHub API endpoints used by the application.
  """
  def base, do: "https://api.github.com"

  def installation_access_token(install_id), do: "/app/installations/#{install_id}/access_tokens"

  def policy_file(owner, repo),
    do: "/repos/#{owner}/#{repo}/contents/#{Application.get_env(:ff_bot, :policy_file)}"

  def team_members(owner, team), do: "/orgs/#{owner}/teams/#{team}/members"

  def compare_refs(owner, repo, base, head),
    do: "/repos/#{owner}/#{repo}/compare/#{base}...#{head}"

  def repo_info(owner, repo), do: "/repos/#{owner}/#{repo}"

  def pull_req_info(owner, repo, number), do: "/repos/#{owner}/#{repo}/pulls/#{number}"

  def issue_comments(owner, repo, number), do: "/repos/#{owner}/#{repo}/issues/#{number}/comments"
end
