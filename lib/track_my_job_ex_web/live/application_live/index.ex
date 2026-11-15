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

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    case JobApplications.get_application(scope, id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Application not found.")}

      application ->
        {:ok, _deleted} = JobApplications.delete_application(scope, application)
        applications = JobApplications.list_applications(scope)

        {:noreply,
         socket
         |> put_flash(:info, "Application deleted.")
         |> assign(:applications_empty?, applications == [])
         |> stream(:applications, applications, reset: true)}
    end
  end
end
