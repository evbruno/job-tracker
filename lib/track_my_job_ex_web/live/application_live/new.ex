defmodule TrackMyJobExWeb.ApplicationLive.New do
  @moduledoc """
  Creates a new job application owned by the current user.
  """

  use TrackMyJobExWeb, :live_view

  alias TrackMyJobEx.JobApplications
  alias TrackMyJobExWeb.ApplicationForm

  @impl true
  def mount(_params, _session, socket) do
    form = JobApplications.new_application_changeset(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "New application")
     |> assign(:form, to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"job_application" => params}, socket) do
    form =
      socket.assigns.current_scope
      |> JobApplications.new_application_changeset(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"job_application" => params}, socket) do
    case JobApplications.create_application(socket.assigns.current_scope, params) do
      {:ok, application} ->
        {:noreply,
         socket
         |> put_flash(:info, "Application created successfully.")
         |> push_navigate(to: ~p"/applications/#{application.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
