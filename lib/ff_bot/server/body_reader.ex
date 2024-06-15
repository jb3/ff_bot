defmodule FFBot.Server.BodyReader do
  @moduledoc """
  Custom body reader for the parsers plug to store a raw copy of the request alongside
  the parsed copy created by the parsers plug.

  This is used so that we can both:
  - parse the body content into JSON with the plug
  - but also generate a signature and compare against the HMAC from GitHub to validate
    requests
  """
  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
    {:ok, body, conn}
  end
end
