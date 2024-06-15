defmodule FFBot.Server.Router do
  @moduledoc """
  Entrypoint Plug router for the FFBot application.
  """
  use Plug.Router

  # Assign each request a unique ID for tracing
  plug(Plug.RequestId, assign_as: :plug_request_id)

  # Find remote IP for each connection
  plug(RemoteIp)

  # Log each request and timings to the console
  plug(Plug.Logger)

  # Parse the body of any request providing that it is a JSON attachment.
  # We use our custom body reader to ensure a raw copy is stored
  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: {:json, :decode, []},
    body_reader: {FFBot.Server.BodyReader, :read_body, []}
  )

  # Plug to perform HMAC calculation and verification, stored in the connection
  # assigns.
  plug(FFBot.HMAC)

  # Plugs to match and dispatch to router routes.
  plug(:match)
  plug(:dispatch)

  # Calculate the uptime of the Erlang VM.
  def uptime do
    {start_time, _} = :erlang.statistics(:wall_clock)
    {d, {h, m, s}} = :calendar.seconds_to_daystime(Integer.floor_div(start_time, 1000))

    [h, m, s] =
      [h, m, s]
      |> Enum.map(&Integer.to_string/1)
      |> Enum.map(&String.pad_leading(&1, 2, "0"))

    "#{d} days, #{h}:#{m}:#{s}"
  end

  # Basic route to return some server info, useful for debugging the application.
  get "/" do
    upt = uptime()

    body = ~s"""
    app: ff_bot
    version: #{Application.spec(:ff_bot)[:vsn]}
    uptime: #{upt}
    """

    conn
    |> put_resp_header("content-type", "text/plain")
    |> send_resp(200, body)
  end

  # Entrypoint for content coming from GitHub.
  post "/hook" do
    # If the connection is validated, proceed.
    if conn.assigns[:validated] do
      # Convert the headers to a map for easy access
      headers = Map.new(conn.req_headers)
      # Convert the event into an atom to use for dispatching
      event = String.to_atom(headers["x-github-event"])

      # If there is an action (i.e. the `created` of `issue_comment.created`), parse that also
      action =
        case conn.body_params["action"] do
          nil -> nil
          some -> String.to_atom(some)
        end

      # Send to the dispatcher to dispatch to relevant handler modules, we do this asynchronously
      # to ensure a fast response time for GitHub.
      spawn(fn ->
        FFBot.Dispatch.dispatch(event, action, conn.body_params)
      end)

      send_resp(conn, 200, "OK")
    else
      # If the content was not validated (either no signature or invalid signature), then
      # return an error
      send_resp(conn, 401, "Signature verification failed")
    end
  end

  # If no other routes/methods match, return a 404 page.
  match _ do
    send_resp(conn, 404, "not found")
  end
end
