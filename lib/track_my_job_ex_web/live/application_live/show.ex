defmodule TrackMyJobExWeb.ApplicationLive.Show do
  @moduledoc """
  Displays a single job application owned by the current user.

  The page shows the application details, its complete status timeline, and a
  form for changing the status with an optional note.
  """

  use TrackMyJobExWeb, :live_view

  alias TrackMyJobEx.JobApplications
  alias TrackMyJobExWeb.Formatters

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope

    case JobApplications.get_application(scope, id) do
      nil ->
        {:ok, not_found(socket)}

      application ->
        history = JobApplications.list_status_history(scope, application)

        {:ok,
         socket
         |> assign(:page_title, application.position)
         |> assign(:application, application)
         |> assign(:statuses, JobApplications.list_statuses())
         |> assign(:status_form, status_form(scope, application))
         |> assign(:status_since, status_since(application, history))
         |> assign(:tags_empty?, application.tags == [])
         |> assign(:history_empty?, history == [])
         |> assign(:pending_delete, nil)
         |> stream(:tags, application.tags)
         |> stream(:history, history)}
    end
  end

  @impl true
  def handle_event("validate_status", %{"status_change" => params}, socket) do
    form =
      socket.assigns.current_scope
      |> JobApplications.change_status_changeset(socket.assigns.application, params)
      |> Map.put(:action, :validate)
      |> to_form(as: :status_change)

    {:noreply, assign(socket, :status_form, form)}
  end

  def handle_event("change_status", %{"status_change" => params}, socket) do
    scope = socket.assigns.current_scope

    case JobApplications.get_application(scope, socket.assigns.application.id) do
      nil ->
        {:noreply, not_found(socket)}

      application ->
        change_status(scope, application, params, socket)
    end
  end

  @impl true
  def handle_event("prompt_delete", _params, socket) do
    {:noreply, assign(socket, :pending_delete, socket.assigns.application)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :pending_delete, nil)}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    scope = socket.assigns.current_scope

    case JobApplications.get_application(scope, socket.assigns.application.id) do
      nil ->
        {:noreply, not_found(socket)}

      application ->
        {:ok, _deleted} = JobApplications.delete_application(scope, application)

        {:noreply,
         socket
         |> put_flash(:info, "Application deleted.")
         |> push_navigate(to: ~p"/applications")}
    end
  end

  @impl true
  def handle_event("archive", _params, socket) do
    scope = socket.assigns.current_scope

    case JobApplications.get_application(scope, socket.assigns.application.id) do
      nil ->
        {:noreply, not_found(socket)}

      application ->
        {:ok, _updated} = JobApplications.archive_application(scope, application)

        reloaded = JobApplications.get_application(scope, application.id)

        {:noreply,
         socket
         |> assign(:application, reloaded)
         |> put_flash(:info, "Application archived.")}
    end
  end

  @impl true
  def handle_event("unarchive", _params, socket) do
    scope = socket.assigns.current_scope

    case JobApplications.get_application(scope, socket.assigns.application.id) do
      nil ->
        {:noreply, not_found(socket)}

      application ->
        {:ok, _updated} = JobApplications.unarchive_application(scope, application)

        reloaded = JobApplications.get_application(scope, application.id)

        {:noreply,
         socket
         |> assign(:application, reloaded)
         |> put_flash(:info, "Application unarchived.")}
    end
  end

  defp change_status(scope, application, params, socket) do
    case JobApplications.change_status(scope, application, params) do
      {:ok, updated} ->
        history = JobApplications.list_status_history(scope, updated)

        {:noreply,
         socket
         |> put_flash(:info, "Status updated.")
         |> assign(:application, updated)
         |> assign(:status_form, status_form(scope, updated))
         |> assign(:status_since, status_since(updated, history))
         |> assign(:history_empty?, history == [])
         |> stream(:history, history, reset: true)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(
           :status_form,
           to_form(%{changeset | action: :insert}, as: :status_change)
         )}
    end
  end

  defp status_form(scope, application) do
    scope
    |> JobApplications.change_status_changeset(application)
    |> to_form(as: :status_change)
  end

  # The most recent history entry is the change into the current status. The
  # context already returns history oldest-first, so the last entry is current.
  defp status_since(application, history) do
    case List.last(history) do
      nil -> application.inserted_at
      entry -> entry.changed_at
    end
  end

  defp not_found(socket) do
    socket
    |> put_flash(:error, "Application not found.")
    |> push_navigate(to: ~p"/applications")
  end
end
