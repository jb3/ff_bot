defmodule FFBot.Dispatch do
  @moduledoc """
  Both the top level dispatcher for incoming commands, mapped by the `dispatch/3` function, or an
  implemented behaviour by handlers that passes in the action and the body of the request.
  """

  @callback dispatch(atom(), map()) :: any()

  alias FFBot.Dispatch

  def dispatch(event, action, body) do
    # Search for a module for the given event type
    module =
      case event do
        :issue_comment -> Dispatch.IssueComment
        _ -> nil
      end

    # If we found the module, we run the dispatch command
    # within it with our arguments
    if module do
      module.dispatch(action, body)
    end
  end
end
