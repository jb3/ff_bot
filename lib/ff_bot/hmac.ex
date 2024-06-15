defmodule FFBot.HMAC do
  @moduledoc """
  Plug to calculate and validate signed HMAC digests from GitHub using the
  pre-configured application secret key.

  Calculated digests are saved to the `:digest` assign on the connection and the
  validation result to the `:validated` assign.
  """
  import Plug.Conn

  require Logger

  @doc false
  @spec init(list()) :: list()
  def init(opts) do
    opts
  end

  # Compute a digest of the provided body and compare it to the provided
  # signature.
  #
  # This uses a cryptographically secure comparison method,
  # `:crypto.hash_equals/2` to ensure constant-time comparisons.
  defp validate(found_sig, body) do
    # Fetch secret
    secret = Application.get_env(:ff_bot, :github_webhook_secret)

    # Decode provided secret to digest bytes
    decoded_sig = Base.decode16(found_sig, case: :mixed)

    case decoded_sig do
      # If decode successful
      {:ok, sig} ->
        # Calculate a digest of the body
        digest = :crypto.mac(:hmac, :sha256, secret, body)

        # Return the calculated digest and whether it matches the header digest
        {Base.encode16(digest), :crypto.hash_equals(digest, sig)}

      # Signature provided in header was not base 16
      :error ->
        Logger.info("Invalid signature provided")
        {nil, false}
    end
  end

  def call(conn, _opts) do
    # Create a new map of the headers
    headers = Map.new(conn.req_headers)

    {conn, validated} =
      case headers["x-hub-signature-256"] do
        # If we have a matching header in the right format
        "sha256=" <> sig ->
          # Run the validation
          {digest, valid} = validate(sig, conn.assigns[:raw_body])
          # Assign the digest to the connection
          {assign(conn, :digest, digest), valid}

        _ ->
          {conn, false}
      end

    # Assign the validation result to the connection and return
    assign(conn, :validated, validated)
  end
end
