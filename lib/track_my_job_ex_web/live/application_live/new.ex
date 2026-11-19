defmodule TrackMyJobExWeb.ApplicationLive.New do
  @moduledoc """
  Creates a new job application owned by the current user.
  """

  use TrackMyJobExWeb, :live_view

  alias TrackMyJobEx.JobApplications
  alias TrackMyJobEx.Tags
  alias TrackMyJobExWeb.ApplicationForm

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    form = JobApplications.new_application_changeset(scope)

    {:ok,
     socket
     |> assign(:page_title, "New application")
     |> assign(:form, to_form(form))
     |> assign(:company_suggestions, JobApplications.list_company_suggestions(scope))
     |> assign(:recruiter_suggestions, JobApplications.list_recruiter_suggestions(scope))
     |> assign(:tags, Tags.list_tags(scope))
     |> assign(:selected_tag_ids, [])
     |> assign(:new_tags, "")
     |> assign(:tag_errors, [])}
  end

  @impl true
  def handle_event("validate", %{"job_application" => params} = all_params, socket) do
    form =
      socket.assigns.current_scope
      |> JobApplications.new_application_changeset(params)
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

    case JobApplications.create_application_with_tags(
           socket.assigns.current_scope,
           params,
           tag_ids,
           new_tags
         ) do
      {:ok, application} ->
        {:noreply,
         socket
         |> put_flash(:info, "Application created successfully.")
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
