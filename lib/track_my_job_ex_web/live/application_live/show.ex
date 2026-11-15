defmodule TrackMyJobExWeb.ApplicationLive.Show do
  @moduledoc """
  Displays a single job application owned by the current user.
  """

  use TrackMyJobExWeb, :live_view

  alias TrackMyJobEx.JobApplications
  alias TrackMyJobExWeb.Formatters

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope

    case JobApplications.get_application(scope, id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Application not found.")
         |> push_navigate(to: ~p"/applications")}

      application ->
        tags = JobApplications.list_application_tags(scope, application)
        history = JobApplications.list_status_history(scope, application)

        {:ok,
         socket
         |> assign(:page_title, application.position)
         |> assign(:application, application)
         |> assign(:tags_empty?, tags == [])
         |> assign(:history_empty?, history == [])
         |> stream(:tags, tags)
         |> stream(:history, history)}
    end
  end
end
