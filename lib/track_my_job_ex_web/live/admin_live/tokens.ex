defmodule TrackMyJobExWeb.AdminLive.Tokens do
  @moduledoc """
  Administrator page for managing MCP tokens across all users.
  """

  use TrackMyJobExWeb, :live_view

  alias TrackMyJobEx.Accounts

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    if Accounts.admin?(scope) do
      tokens = unwrap(Accounts.list_all_mcp_tokens(scope))
      users = unwrap(Accounts.list_users(scope))

      {:ok,
       socket
       |> assign(:page_title, "Admin · MCP tokens")
       |> assign(:tokens, tokens)
       |> assign(:tokens_empty?, tokens == [])
       |> assign(:users, users)
       |> assign(:pending_delete, nil)
       |> assign(:new_token, nil)
       |> assign(
         :create_form,
         to_form(%{"user_id" => "", "name" => "", "expires_in" => ""}, as: :token)
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "You are not authorized to view this page.")
       |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("create", %{"token" => params}, socket) do
    scope = socket.assigns.current_scope

    attrs = build_attrs(params)

    case Accounts.create_mcp_token_for_user(scope, params["user_id"], attrs) do
      {:ok, _token, plaintext} ->
        tokens = unwrap(Accounts.list_all_mcp_tokens(scope))

        {:noreply,
         socket
         |> assign(:tokens, tokens)
         |> assign(:tokens_empty?, tokens == [])
         |> assign(:new_token, plaintext)
         |> assign(
           :create_form,
           to_form(%{"user_id" => "", "name" => "", "expires_in" => ""}, as: :token)
         )
         |> put_flash(:info, "Token created. Copy it now; it will not be shown again.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "User not found.")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:create_form, to_form(changeset, as: :token))
         |> put_flash(:error, format_errors(changeset))}
    end
  end

  def handle_event("dismiss_token", _params, socket) do
    {:noreply, assign(socket, :new_token, nil)}
  end

  def handle_event("prompt_delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    case Enum.find(
           unwrap(Accounts.list_all_mcp_tokens(scope)),
           &(to_string(&1.id) == to_string(id))
         ) do
      nil -> {:noreply, put_flash(socket, :error, "Token not found.")}
      token -> {:noreply, assign(socket, :pending_delete, token)}
    end
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :pending_delete, nil)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    case Accounts.revoke_mcp_token(scope, id) do
      {:ok, _token} ->
        tokens = unwrap(Accounts.list_all_mcp_tokens(scope))

        {:noreply,
         socket
         |> assign(:tokens, tokens)
         |> assign(:tokens_empty?, tokens == [])
         |> assign(:pending_delete, nil)
         |> put_flash(:info, "Token revoked.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Token not found.")}
    end
  end

  defp unwrap({:ok, value}), do: value
  defp unwrap(_), do: []

  defp build_attrs(params) do
    name = Map.get(params, "name", "") |> String.trim()
    expires_in = Map.get(params, "expires_in", "") |> String.trim()

    attrs = %{"name" => name}

    case Integer.parse(expires_in) do
      {days, ""} when days > 0 ->
        expires_at = DateTime.add(DateTime.utc_now(:second), days * 24 * 60 * 60, :second)
        Map.put(attrs, "expires_at", expires_at)

      _ ->
        attrs
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
