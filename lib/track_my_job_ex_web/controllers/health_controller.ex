defmodule TrackMyJobExWeb.HealthController do
  @moduledoc """
  Lightweight liveness/readiness endpoint for load balancers and uptime checks.

  The endpoint intentionally does not require authentication and returns no
  application data. It only reports whether the database answers a trivial
  query, so a load balancer can stop routing traffic when SQLite is unavailable.
  """

  use TrackMyJobExWeb, :controller

  alias TrackMyJobEx.Repo

  @doc """
  Returns `200 ok` when the database is reachable, otherwise `503 unavailable`.
  """
  def index(conn, _params) do
    conn = put_resp_content_type(conn, "text/plain")

    case health_check() do
      :ok -> send_resp(conn, 200, "ok\n")
      :error -> send_resp(conn, 503, "unavailable\n")
    end
  end

  defp health_check do
    case Repo.query("SELECT 1") do
      {:ok, _result} -> :ok
      {:error, _reason} -> :error
    end
  rescue
    _exception -> :error
  end
end
