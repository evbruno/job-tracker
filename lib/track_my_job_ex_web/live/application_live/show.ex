defmodule TrackMyJobExWeb.ApplicationLive.Show do
  @moduledoc """
  Displays a single job application owned by the current user.
  """

  use TrackMyJobExWeb, :live_view

  alias TrackMyJobEx.JobApplications

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case JobApplications.get_application(socket.assigns.current_scope, id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Application not found.")
         |> push_navigate(to: ~p"/applications")}

      application ->
        {:ok,
         socket
         |> assign(:page_title, application.position)
         |> assign(:application, application)}
    end
  end
end
