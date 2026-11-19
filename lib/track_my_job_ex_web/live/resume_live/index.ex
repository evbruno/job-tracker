defmodule TrackMyJobExWeb.ResumeLive.Index do
  @moduledoc """
  Lists the current user's resumes, most recently updated first.

  Resumes are independent versions; this page is a simple index with no
  filters or pagination.
  """

  use TrackMyJobExWeb, :live_view

  alias TrackMyJobEx.Resumes
  alias TrackMyJobExWeb.Formatters

  @impl true
  def mount(_params, _session, socket) do
    resumes = Resumes.list_resumes(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "Resumes")
     |> assign(:resume_count, length(resumes))
     |> assign(:resumes_empty?, resumes == [])
     |> stream(:resumes, resumes)}
  end
end
