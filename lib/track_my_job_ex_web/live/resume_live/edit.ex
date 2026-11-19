defmodule TrackMyJobExWeb.ResumeLive.Edit do
  @moduledoc """
  Edits a resume owned by the current user.
  """

  use TrackMyJobExWeb, :live_view

  alias TrackMyJobEx.Resumes
  alias TrackMyJobEx.Tags
  alias TrackMyJobExWeb.ResumeForm

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope

    case Resumes.get_resume(scope, id) do
      nil ->
        {:ok, not_found(socket)}

      resume ->
        form =
          scope
          |> Resumes.change_resume(resume)
          |> to_form()

        selected_tag_ids =
          Resumes.list_resume_tags(scope, resume) |> Enum.map(& &1.id)

        {:ok,
         socket
         |> assign(:page_title, "Edit resume")
         |> assign(:resume, resume)
         |> assign(:form, form)
         |> assign(:tags, Tags.list_tags(scope))
         |> assign(:selected_tag_ids, selected_tag_ids)
         |> assign(:new_tags, "")
         |> assign(:tag_errors, [])}
    end
  end

  @impl true
  def handle_event("validate", %{"resume" => params} = all_params, socket) do
    form =
      socket.assigns.current_scope
      |> Resumes.change_resume(socket.assigns.resume, params)
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

    case Resumes.update_resume_with_tags(
           socket.assigns.current_scope,
           socket.assigns.resume,
           params,
           tag_ids,
           new_tags
         ) do
      {:ok, resume} ->
        {:noreply,
         socket
         |> put_flash(:info, "Resume updated successfully.")
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

  defp not_found(socket) do
    socket
    |> put_flash(:error, "Resume not found.")
    |> push_navigate(to: ~p"/resumes")
  end
end
