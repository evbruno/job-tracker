defmodule TrackMyJobExWeb.DashboardLive do
  @moduledoc """
  Placeholder dashboard shown at the root path.

  Authentication is introduced in Phase 2. For now the page provides a small
  LiveView interaction so that the LiveView wiring can be verified.
  """

  use TrackMyJobExWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Dashboard", count: 0)}
  end

  @impl true
  def handle_event("increment", _params, socket) do
    {:noreply, update(socket, :count, &(&1 + 1))}
  end

  def handle_event("decrement", _params, socket) do
    {:noreply, update(socket, :count, &max(&1 - 1, 0))}
  end

  def handle_event("reset", _params, socket) do
    {:noreply, assign(socket, :count, 0)}
  end
end
