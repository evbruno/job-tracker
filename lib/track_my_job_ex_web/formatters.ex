defmodule TrackMyJobExWeb.Formatters do
  @moduledoc """
  Helpers for displaying domain values in templates.

  Timestamps are stored and displayed in UTC for the initial version.
  """

  @doc """
  Formats a UTC datetime for display.

      iex> TrackMyJobExWeb.Formatters.format_utc_datetime(~U[2026-11-14 09:30:00Z])
      "2026-11-14 09:30 UTC"
  """
  def format_utc_datetime(nil), do: ""

  def format_utc_datetime(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M UTC")
  end

  @doc """
  Returns the URL when it is a safe absolute `http`/`https` URL, otherwise `nil`.
  """
  def safe_http_url(url) when is_binary(url) do
    case URI.new(url) do
      {:ok, %URI{scheme: scheme, host: host}}
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        url

      _ ->
        nil
    end
  end

  def safe_http_url(_url), do: nil
end
