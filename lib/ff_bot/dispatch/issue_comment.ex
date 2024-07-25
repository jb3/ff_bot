defmodule FFBot.Dispatch.IssueComment do
  @moduledoc """
  Handles incoming issue comment creation events. Whilst the name is issues, pull request
  comments (like our merge command) are classed under the same event
  """
  @behaviour FFBot.Dispatch

  alias FFBot.{Auth.InstallationTokenServer, GitHub, Policy, Encouragement}

  require Logger

  @impl true
  def dispatch(:created, body) do
    # If the pull request attribute of the issue is undefined, it's just a regular issue
    if body["issue"]["pull_request"] != nil do
      # If it is defined, the comment is on a PR
      case body["comment"]["body"] do
        # If it starts with "/" and matches one of our commands, pass to the command runner
        "/" <> command when command in ["merge"] -> command_dispatch(command, body)
        _ -> nil
      end
    else
      Logger.info("Ignoring comment event from non-PR")
    end
  end

  @impl true
  def dispatch(_other, _body) do
    # no-op
  end

  defp command_dispatch(command, body) do
    Logger.info("Received command: #{command}")
    # Generate a new token for this specific installation
    token = InstallationTokenServer.get_token(body["installation"]["id"])

    owner = body["repository"]["owner"]["login"]
    repo = body["repository"]["name"]

    # Attempt to fetch the contents of the policy file, parsed into a struct
    maybe_policy =
      Policy.get_policy_file(
        token,
        owner,
        repo
      )

    case maybe_policy do
      # If we found the policy file, the repo is enabled and we can test for user permission
      {:ok, policy} ->
        # We test the policy to see if the user is explicitly named or in a valid team
        # to operate on this repo
        if Policy.test_permission(token, policy, body["comment"]["user"]["login"]) do
          run_command(token, command, body)
        else
          # If they are not, log a notice of this failed check
          Logger.info(
            "User #{body["comment"]["user"]["login"]} failed permissions check on #{owner}/#{repo}"
          )
        end

      {:error, reason} ->
        # If the policy could not be fetched, log an error for that stating the exception
        Logger.warning("Repo #{owner}/#{repo} has bad policy, error code: #{reason}")
    end
  end

  # Top level command dispatcher once we have done policy checks
  defp run_command(token, command, body) do
    case command do
      "merge" -> do_merge(token, body)
    end
  end

  defp do_merge(token, body) do
    # Assign some convenience variables from body content
    owner = body["repository"]["owner"]["login"]
    repo = body["repository"]["name"]
    pr_num = body["issue"]["number"]

    Logger.debug("Fetching repo details")

    # Fetch the repo details, which we will use to determine the default branch
    # which is used later in the comparison process
    {200, repo_details} =
      GitHub.Request.request(
        :get,
        GitHub.Endpoint.repo_info(owner, repo),
        auth: {:token, token}
      )

    Logger.debug("Fetching PR details")

    # Fetch details on the PR from GitHub, which we will later use to help determine
    # if the branches are in a state where a fast-forward merge can be performed
    {200, pr_details} =
      GitHub.Request.request(
        :get,
        GitHub.Endpoint.pull_req_info(owner, repo, pr_num),
        auth: {:token, token}
      )

    Logger.debug("Comparing tips of branches")

    # Using the information collected in the prior requests, call the GitHub API
    # to determine the commit diff between two branches. This will tell us whether
    # the branches are up to date (and so, whether a fast-forward merge can take place)
    {200, comparison_details} =
      GitHub.Request.request(
        :get,
        GitHub.Endpoint.compare_refs(
          owner,
          repo,
          repo_details["default_branch"],
          pr_details["head"]["label"]
        ),
        auth: {:token, token}
      )

    # If the status is anything but "ahead" (branch only has new commits and is up to date with default),
    # then we return an error onto the PR
    if comparison_details["status"] != "ahead" do
      Logger.info("Aborting merge attempt, branch was #{comparison_details["status"]}")

      GitHub.Request.comment(
        token,
        owner,
        repo,
        pr_num,
        :error,
        "Branch is in `#{comparison_details["status"]}` status, ahead by " <>
          "#{comparison_details["ahead_by"]} commits and behind by " <>
          "#{comparison_details["behind_by"]} commits. Please update the branch " <>
          "to reflect changes on `#{repo_details["default_branch"]}` and try again, " <>
          "or merge locally." <> Encouragement.maybe_encouraging_comment()
      )
    else
      Logger.info("Triggering merger...")
      # If the PR status was "ahead", we can start the merge process.
      spawn(fn ->
        GitHub.Merger.start_merge(token, repo_details, pr_details)
      end)
    end
  end
end
