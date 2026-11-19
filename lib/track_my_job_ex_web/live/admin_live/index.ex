defmodule TrackMyJobExWeb.AdminLive.Index do
  @moduledoc """
  Administrator page for managing user accounts.
  """

  use TrackMyJobExWeb, :live_view

  alias TrackMyJobEx.Accounts

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    if Accounts.admin?(scope) do
      users = unwrap(Accounts.list_users(scope))

      {:ok,
       socket
       |> assign(:page_title, "Admin · Users")
       |> assign(:users, users)
       |> assign(:users_empty?, users == [])
       |> assign(:pending_delete, nil)
       |> assign(
         :create_form,
         to_form(%{"email" => "", "password" => "", "is_admin" => "false"}, as: :user)
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "You are not authorized to view this page.")
       |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("create", %{"user" => params}, socket) do
    scope = socket.assigns.current_scope

    attrs = %{
      "email" => params["email"],
      "password" => params["password"],
      "is_admin" => params["is_admin"] == "true"
    }

    case Accounts.create_user(scope, attrs) do
      {:ok, _user} ->
        users = unwrap(Accounts.list_users(scope))

        {:noreply,
         socket
         |> assign(:users, users)
         |> assign(:users_empty?, users == [])
         |> assign(
           :create_form,
           to_form(%{"email" => "", "password" => "", "is_admin" => "false"}, as: :user)
         )
         |> put_flash(:info, "User created.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized.")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:create_form, to_form(changeset, as: :user))
         |> put_flash(:error, format_errors(changeset))}
    end
  end

  def handle_event("prompt_delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    case find_user(scope, id) do
      nil -> {:noreply, put_flash(socket, :error, "User not found.")}
      user -> {:noreply, assign(socket, :pending_delete, user)}
    end
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :pending_delete, nil)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    case Accounts.delete_user(scope, id) do
      {:ok, _user} ->
        users = unwrap(Accounts.list_users(scope))

        {:noreply,
         socket
         |> assign(:users, users)
         |> assign(:users_empty?, users == [])
         |> assign(:pending_delete, nil)
         |> put_flash(:info, "User deleted.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized.")}

      {:error, :cannot_delete_self} ->
        {:noreply, put_flash(socket, :error, "You cannot delete your own account.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "User not found.")}
    end
  end

  def handle_event("toggle_admin", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    user = find_user(scope, id)

    if user do
      new_value = !user.is_admin

      case Accounts.set_user_admin(scope, id, new_value) do
        {:ok, _user} ->
          users = unwrap(Accounts.list_users(scope))

          {:noreply,
           socket
           |> assign(:users, users)
           |> put_flash(:info, "User updated.")}

        {:error, :unauthorized} ->
          {:noreply, put_flash(socket, :error, "You are not authorized.")}

        {:error, :not_found} ->
          {:noreply, put_flash(socket, :error, "User not found.")}
      end
    else
      {:noreply, put_flash(socket, :error, "User not found.")}
    end
  end

  defp unwrap({:ok, users}), do: users
  defp unwrap(_), do: []

  defp find_user(scope, id) do
    case Accounts.list_users(scope) do
      {:ok, users} -> Enum.find(users, &(to_string(&1.id) == to_string(id)))
      _ -> nil
    end
  end

  defp format_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(&interpolate/1)
    |> Enum.map_join(", ", fn {field, messages} ->
      "#{field} #{Enum.join(messages, ", ")}"
    end)
  end

  defp interpolate({message, opts}) do
    Enum.reduce(opts, message, fn {key, value}, acc ->
      placeholder = "%{#{key}}"

      if String.contains?(acc, placeholder) do
        String.replace(acc, placeholder, to_string(value))
      else
        acc
      end
    end)
  end
end
