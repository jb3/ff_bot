defmodule FFBot.GitHub.Merger do
  @moduledoc """
  Utilities that use the Git CLI to perform a merge.

  A merge works as follows:
  - The repo is cloned using the provided access tokens
  - The merge is performed by running `git merge` with the `--ff-only` option
  - The changes are pushed to GitHub
  - Temporary files are cleaned up and removed
  """

  require Logger

  alias FFBot.GitHub.Request

  def start_merge(token, repo, pull_request) do
    Logger.metadata(
      repo: "#{repo["owner"]["login"]}/#{repo["name"]}",
      issue: pull_request["number"]
    )

    Logger.info("Cloning repository...")

    {directory, cloned} = clone_repo(token, repo)

    Logger.info("Cloned to #{directory}, merging branch")

    merge_pull_req(cloned, pull_request)

    Logger.info("Pushing changes to remote")

    push_changes(cloned)

    Logger.info("Running clearup")

    File.rm_rf(directory)

    Logger.info("Send confirmation onto pull request")

    Request.comment(
      token,
      repo["owner"]["login"],
      repo["name"],
      pull_request["number"],
      :success,
      "Successfully fast-forwarded commits from `#{pull_request["head"]["label"]}` " <>
        "onto `#{repo["default_branch"]}`" <> maybe_propaganda()
    )
  end

  defp clone_repo(token, repo) do
    owner = repo["owner"]["login"]
    name = repo["name"]
    {:ok, dir_path} = Temp.mkdir("#{owner}-#{name}")

    {:ok, repo} =
      Git.clone(["https://x-access-token:#{token}@github.com/#{owner}/#{name}.git", dir_path])

    {dir_path, repo}
  end

  defp merge_pull_req(cloned_repo, pull_request) do
    {:ok, _} = Git.merge(cloned_repo, ["--ff-only", "origin/#{pull_request["head"]["ref"]}"])
  end

  defp push_changes(cloned) do
    {:ok, _} = Git.push(cloned)
  end

  defp maybe_propaganda do
    if Application.get_env(:ff_bot, :disable_propaganda?) != nil and :rand.uniform() < 0.01 do
      ". Glory to Arstotzka!"
    else
      ""
    end
  end
end
