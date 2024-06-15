defmodule FFBot.Auth.BearerToken do
  @moduledoc """
  Joken Token configuration to store generated bearer tokens signed with the
  GitHub client secret.
  """
  use Joken.Config
end
