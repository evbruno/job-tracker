defmodule TrackMyJobExWeb.ResumeLive.Show do
  @moduledoc """
  Displays a single resume owned by the current user.
  """

  use TrackMyJobExWeb, :live_view

  alias TrackMyJobEx.Resumes
  alias TrackMyJobExWeb.Formatters

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Resumes.get_resume(socket.assigns.current_scope, id) do
      nil ->
        {:ok, not_found(socket)}

      resume ->
        {:ok,
         socket
         |> assign(:page_title, resume.title)
         |> assign(:resume, resume)
         |> assign(:links, link_rows(resume))
         |> assign(:tags_empty?, resume.tags == [])
         |> assign(:pending_delete, nil)
         |> stream(:tags, resume.tags)}
    end
  end

  @impl true
  def handle_event("prompt_delete", _params, socket) do
    {:noreply, assign(socket, :pending_delete, socket.assigns.resume)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :pending_delete, nil)}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    scope = socket.assigns.current_scope

    case Resumes.get_resume(scope, socket.assigns.resume.id) do
      nil ->
        {:noreply, not_found(socket)}

      resume ->
        {:ok, _deleted} = Resumes.delete_resume(scope, resume)

        {:noreply,
         socket
         |> put_flash(:info, "Resume deleted.")
         |> push_navigate(to: ~p"/resumes")}
    end
  end

  defp not_found(socket) do
    socket
    |> put_flash(:error, "Resume not found.")
    |> push_navigate(to: ~p"/resumes")
  end

  defp link_rows(resume) do
    [
      %{
        id: "resume-linkedin-url",
        label: "LinkedIn",
        url: Formatters.safe_http_url(resume.linkedin_url)
      },
      %{
        id: "resume-github-url",
        label: "GitHub",
        url: Formatters.safe_http_url(resume.github_url)
      },
      %{
        id: "resume-portfolio-url",
        label: "Portfolio",
        url: Formatters.safe_http_url(resume.portfolio_url)
      }
    ]
  end
end
