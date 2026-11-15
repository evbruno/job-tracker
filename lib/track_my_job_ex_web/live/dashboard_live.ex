defmodule TrackMyJobExWeb.DashboardLive do
  @moduledoc """
  Authenticated landing page.

  Application and tag management arrive in a later phase; for now this page
  confirms that the user is signed in and that their tenant scope is available.
  """

  use TrackMyJobExWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Dashboard")}
  end
end
