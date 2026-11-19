defmodule TrackMyJobExWeb.ApplicationLive.Edit do
  @moduledoc """
  Edits the details of a job application owned by the current user.

  Status changes are handled on the application details page and are not part of
  this form.
  """

  use TrackMyJobExWeb, :live_view

  alias TrackMyJobEx.JobApplications
  alias TrackMyJobEx.Tags
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

        scope = socket.assigns.current_scope

        selected_tag_ids =
          JobApplications.list_application_tags(scope, application) |> Enum.map(& &1.id)

        {:ok,
         socket
         |> assign(:page_title, "Edit application")
         |> assign(:application, application)
         |> assign(:form, form)
         |> assign(:company_suggestions, JobApplications.list_company_suggestions(scope))
         |> assign(:recruiter_suggestions, JobApplications.list_recruiter_suggestions(scope))
         |> assign(:tags, Tags.list_tags(scope))
         |> assign(:selected_tag_ids, selected_tag_ids)
         |> assign(:new_tags, "")
         |> assign(:tag_errors, [])}
    end
  end

  @impl true
  def handle_event("validate", %{"job_application" => params} = all_params, socket) do
    form =
      socket.assigns.current_scope
      |> JobApplications.change_application(socket.assigns.application, params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:selected_tag_ids, Map.get(all_params, "tag_ids", []))
     |> assign(:new_tags, Map.get(all_params, "new_tags", ""))
     |> assign(:tag_errors, [])}
  end

  def handle_event("save", %{"job_application" => params} = all_params, socket) do
    tag_ids = Map.get(all_params, "tag_ids", [])
    new_tags = ApplicationForm.parse_new_tag_names(Map.get(all_params, "new_tags", ""))

    case JobApplications.update_application_with_tags(
           socket.assigns.current_scope,
           socket.assigns.application,
           params,
           tag_ids,
           new_tags
         ) do
      {:ok, application} ->
        {:noreply,
         socket
         |> put_flash(:info, "Application updated successfully.")
         |> push_navigate(to: ~p"/applications/#{application.id}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(changeset))
         |> assign(:selected_tag_ids, tag_ids)
         |> assign(:new_tags, Map.get(all_params, "new_tags", ""))
         |> assign(:tag_errors, ApplicationForm.tag_errors(changeset))}
    end
  end
end
