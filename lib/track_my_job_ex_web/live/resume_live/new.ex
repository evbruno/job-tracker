defmodule TrackMyJobExWeb.ResumeLive.New do
  @moduledoc """
  Creates a new resume owned by the current user.

  The email is prefilled from the signed-in user's account and remains editable.
  """

  use TrackMyJobExWeb, :live_view

  alias TrackMyJobEx.Resumes
  alias TrackMyJobEx.Tags
  alias TrackMyJobExWeb.ResumeForm

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    form = Resumes.new_resume_changeset(scope)

    {:ok,
     socket
     |> assign(:page_title, "New resume")
     |> assign(:form, to_form(form))
     |> assign(:tags, Tags.list_tags(scope))
     |> assign(:selected_tag_ids, [])
     |> assign(:new_tags, "")
     |> assign(:tag_errors, [])}
  end

  @impl true
  def handle_event("validate", %{"resume" => params} = all_params, socket) do
    form =
      socket.assigns.current_scope
      |> Resumes.new_resume_changeset(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:selected_tag_ids, Map.get(all_params, "tag_ids", []))
     |> assign(:new_tags, Map.get(all_params, "new_tags", ""))
     |> assign(:tag_errors, [])}
  end

  def handle_event("save", %{"resume" => params} = all_params, socket) do
    tag_ids = Map.get(all_params, "tag_ids", [])
    new_tags = ResumeForm.parse_new_tag_names(Map.get(all_params, "new_tags", ""))

    case Resumes.create_resume_with_tags(
           socket.assigns.current_scope,
           params,
           tag_ids,
           new_tags
         ) do
      {:ok, resume} ->
        {:noreply,
         socket
         |> put_flash(:info, "Resume created successfully.")
         |> push_navigate(to: ~p"/resumes/#{resume.id}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(changeset))
         |> assign(:selected_tag_ids, tag_ids)
         |> assign(:new_tags, Map.get(all_params, "new_tags", ""))
         |> assign(:tag_errors, ResumeForm.tag_errors(changeset))}
    end
  end
end
