defmodule TrackMyJobExWeb.ApplicationLive.Index do
  @moduledoc """
  Lists the current user's job applications, newest first.
  """

  use TrackMyJobExWeb, :live_view

  alias TrackMyJobEx.JobApplications
  alias TrackMyJobExWeb.Formatters

  @impl true
  def mount(_params, _session, socket) do
    applications = JobApplications.list_applications(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "Applications")
     |> assign(:applications_empty?, applications == [])
     |> stream(:applications, applications)}
  end
end
