defmodule TrackMyJobExWeb.TagLive.Index do
  @moduledoc """
  Lists, renames, and deletes the current user's tags.
  """

  use TrackMyJobExWeb, :live_view

  alias TrackMyJobEx.Tags

  @impl true
  def mount(_params, _session, socket) do
    tags = Tags.list_tags(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "Tags")
     |> assign(:tags_empty?, tags == [])
     |> assign(:editing_tag_id, nil)
     |> assign(:rename_form, nil)
     |> stream(:tags, tags)}
  end

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    case Tags.get_tag(scope, id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Tag not found.")}

      tag ->
        {:noreply,
         socket
         |> clear_edit()
         |> assign(:editing_tag_id, tag.id)
         |> assign(:rename_form, to_form(Tags.change_tag(scope, tag)))
         |> stream_insert(:tags, tag)}
    end
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, clear_edit(socket)}
  end

  def handle_event("rename", %{"tag" => %{"id" => id, "name" => name}}, socket) do
    scope = socket.assigns.current_scope

    case Tags.get_tag(scope, id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Tag not found.")
         |> clear_edit()}

      tag ->
        case Tags.update_tag(scope, tag, %{name: name}) do
          {:ok, _tag} ->
            tags = Tags.list_tags(scope)

            {:noreply,
             socket
             |> put_flash(:info, "Tag renamed.")
             |> assign(:tags_empty?, tags == [])
             |> assign(:editing_tag_id, nil)
             |> assign(:rename_form, nil)
             |> stream(:tags, tags, reset: true)}

          {:error, changeset} ->
            {:noreply,
             socket
             |> assign(:editing_tag_id, tag.id)
             |> assign(:rename_form, to_form(changeset))
             |> stream_insert(:tags, tag)}
        end
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    case Tags.get_tag(scope, id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Tag not found.")}

      tag ->
        {:ok, _deleted} = Tags.delete_tag(scope, tag)
        tags = Tags.list_tags(scope)

        {:noreply,
         socket
         |> put_flash(:info, "Tag deleted.")
         |> assign(:tags_empty?, tags == [])
         |> assign(:editing_tag_id, nil)
         |> assign(:rename_form, nil)
         |> stream(:tags, tags, reset: true)}
    end
  end

  defp clear_edit(socket) do
    case socket.assigns.editing_tag_id do
      nil ->
        socket

      id ->
        socket = assign(socket, :editing_tag_id, nil)
        socket = assign(socket, :rename_form, nil)

        case Tags.get_tag(socket.assigns.current_scope, id) do
          nil -> socket
          tag -> stream_insert(socket, :tags, tag)
        end
    end
  end
end
