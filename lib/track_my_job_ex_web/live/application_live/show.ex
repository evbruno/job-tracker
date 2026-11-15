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

  @impl true
  def handle_event("delete", _params, socket) do
    scope = socket.assigns.current_scope

    case JobApplications.get_application(scope, socket.assigns.application.id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Application not found.")
         |> push_navigate(to: ~p"/applications")}

      application ->
        {:ok, _deleted} = JobApplications.delete_application(scope, application)

        {:noreply,
         socket
         |> put_flash(:info, "Application deleted.")
         |> push_navigate(to: ~p"/applications")}
    end
  end
end
