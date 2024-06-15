# Fast Forward Bot

A GitHub bot allowing for quick and easy fast-forward merges triggered by PR
comments.

You may want to use this application if you want to rebase your commits to your
master branch from within GitHub whilst preserving author signature information
and avoiding the rewriting of commits.

## Deployment


### Creating the application

Follow the guide [here](github-guide) to create a new GitHub app.

The following permissions are required:
- Contents: Read & Write
- Issues: Read & Write
- Pull Requests: Read & Write

The following webhook events must be selected:
- Issue comment

Set the webhook URL to `https://your-prod-domain.com/hook` and select a secure
client secret.

Once created, generate a client secret and keep a hold of this value for later.

[github-guide]: https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app

### Deployment

A Docker image is published at [`ghcr.io/jb3/ff_bot:latest`](img) which can be used to
deploy this application.

The following environment variables must be set:

| Variable                | Description                                                                                                         |
|-------------------------|---------------------------------------------------------------------------------------------------------------------|
| `GITHUB_WEBHOOK_SECRET` | A secure secret configured in GitHub and your app to validate webhook payloads. Same as the preference set earlier. |
| `GITHUB_CLIENT_ID`      | The client ID of your created GitHub app                                                                            |
| `GITHUB_CLIENT_SECRET`  | The client secret certificate of your GitHub app used to sign token requests.                                       |

You can also optionally set these variables:

| Variable         | Description                                           | Default              |
|------------------|-------------------------------------------------------|----------------------|
| `FF_POLICY_FILE` | The file to read for policy on who can perform merges | `.github/ff-bot.yml` |
| `FF_LISTEN_PORT` | The HTTP port for the service to listen on            | 4000                 |

[img]: https://ghcr.io/jb3/ff_bot

## Usage

Once deployed, follow GitHub's instructions to install to your own
account/organisation and select the repositories to use.

For a repository to use it, it must have a review policy at `.github/ff-bot.yml`
(or whatever you have set `FF_POLICY_FILE` to).

An example policy looks like this:

``` yaml
users:
- jb3
teams:
- python-discord/devops
```

Once a user wants to merge a PR, all they have to do is run `/merge` in the PR
comments. If the branch is up to date the merge will take place, if not then the
bot will reply with the branch status.

For the merge to complete, the user must be in the policy file directly or in a
team mentioned in the policy file.

Providing the user is in the policy file and the branch in question is up to
date with main (i.e. is only "ahead" of main, no divergence), the merge will
take place and GitHub will automatically close the Pull Request as all commits
are now present on your primary branch.
