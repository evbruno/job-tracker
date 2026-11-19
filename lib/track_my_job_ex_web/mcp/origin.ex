defmodule TrackMyJobExWeb.MCP.Origin do
  @moduledoc """
  Origin allow-list for browser requests to the MCP endpoint.

  Native MCP clients do not send an `Origin` header and are not affected. Only
  browsers send one, so this check exists to block DNS-rebinding attempts. The
  list is read at runtime from `:mcp_allowed_origins`, which operators can
  extend without recompiling.
  """

  @default_origins ["http://localhost:4000"]

  @doc """
  Returns true when the given Origin header value is allowed.
  """
  def allowed?(origin) when is_binary(origin) do
    origin in allowed_origins()
  end

  def allowed?(_origin), do: false

  @doc """
  Returns the configured list of allowed origins.
  """
  def allowed_origins do
    Application.get_env(:track_my_job_ex, :mcp_allowed_origins, @default_origins)
  end
end
