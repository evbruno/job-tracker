defmodule TrackMyJobExWeb.ApplicationLive.Edit do
  @moduledoc """
  Edits the details of a job application owned by the current user.

  Status changes are handled separately in Phase 5 and are not part of this
  form.
  """

  use TrackMyJobExWeb, :live_view

  alias TrackMyJobEx.JobApplications
  alias TrackMyJobExWeb.ApplicationForm

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case JobApplications.get_application(socket.assigns.current_scope, id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Application not found.")
         |> push_navigate(to: ~p"/applications")}

      application ->
        form =
          socket.assigns.current_scope
          |> JobApplications.change_application(application)
          |> to_form()

        {:ok,
         socket
         |> assign(:page_title, "Edit application")
         |> assign(:application, application)
         |> assign(:form, form)}
    end
  end

  @impl true
  def handle_event("validate", %{"job_application" => params}, socket) do
    form =
      socket.assigns.current_scope
      |> JobApplications.change_application(socket.assigns.application, params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"job_application" => params}, socket) do
    case JobApplications.update_application(
           socket.assigns.current_scope,
           socket.assigns.application,
           params
         ) do
      {:ok, application} ->
        {:noreply,
         socket
         |> put_flash(:info, "Application updated successfully.")
         |> push_navigate(to: ~p"/applications/#{application.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
