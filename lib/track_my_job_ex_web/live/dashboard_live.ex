defmodule TrackMyJobExWeb.DashboardLive do
  @moduledoc """
  Authenticated landing page.

  Displays tenant-scoped summary metrics and shortcuts to key sections.
  """

  use TrackMyJobExWeb, :live_view

  alias TrackMyJobEx.Dashboard

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:counts, Dashboard.counts(socket.assigns.current_scope))}
  end
end
