defmodule TrackMyJobExWeb.McpTokenLive.Index do
  @moduledoc """
  Lists, creates, and revokes the signed-in user's MCP personal access tokens.
  """

  use TrackMyJobExWeb, :live_view

  alias TrackMyJobEx.Accounts
  alias TrackMyJobEx.MCP.OAuth

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    tokens = Accounts.list_mcp_tokens(scope)
    oauth_connections = OAuth.list_connections(scope)

    {:ok,
     socket
     |> assign(:page_title, "MCP")
     |> assign(:tokens, tokens)
     |> assign(:oauth_connections, oauth_connections)
     |> assign(:tokens_empty?, tokens == [] and oauth_connections == [])
     |> assign(:pending_delete, nil)
     |> assign(:pending_oauth_revoke, nil)
     |> assign(:new_token, nil)
     |> assign(:create_form, to_form(%{"name" => "", "expires_in" => ""}, as: :token))}
  end

  @impl true
  def handle_event("create", %{"token" => params}, socket) do
    scope = socket.assigns.current_scope
    attrs = build_attrs(params)

    case Accounts.create_mcp_token(scope, attrs) do
      {:ok, _token, plaintext} ->
        tokens = Accounts.list_mcp_tokens(scope)
        oauth_connections = OAuth.list_connections(scope)

        {:noreply,
         socket
         |> assign(:tokens, tokens)
         |> assign(:oauth_connections, oauth_connections)
         |> assign(:tokens_empty?, tokens == [] and oauth_connections == [])
         |> assign(:new_token, plaintext)
         |> assign(:create_form, to_form(%{"name" => "", "expires_in" => ""}, as: :token))
         |> put_flash(:info, "Token created. Copy it now; it will not be shown again.")}

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

    case Accounts.get_mcp_token(scope, id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Token not found.")}

      token ->
        {:noreply, assign(socket, :pending_delete, token)}
    end
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :pending_delete, nil)}
  end

  def handle_event("prompt_revoke_oauth", %{"id" => family_id}, socket) do
    scope = socket.assigns.current_scope

    case Enum.find(OAuth.list_connections(scope), &(&1.family_id == family_id)) do
      nil -> {:noreply, put_flash(socket, :error, "OAuth connection not found.")}
      connection -> {:noreply, assign(socket, :pending_oauth_revoke, connection)}
    end
  end

  def handle_event("cancel_revoke_oauth", _params, socket) do
    {:noreply, assign(socket, :pending_oauth_revoke, nil)}
  end

  def handle_event("revoke_oauth", %{"id" => family_id}, socket) do
    scope = socket.assigns.current_scope

    case OAuth.revoke_connection(scope, family_id) do
      :ok ->
        tokens = Accounts.list_mcp_tokens(scope)
        oauth_connections = OAuth.list_connections(scope)

        {:noreply,
         socket
         |> assign(:tokens, tokens)
         |> assign(:oauth_connections, oauth_connections)
         |> assign(:tokens_empty?, tokens == [] and oauth_connections == [])
         |> assign(:pending_oauth_revoke, nil)
         |> put_flash(:info, "OAuth connection revoked.")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> assign(:pending_oauth_revoke, nil)
         |> put_flash(:error, "OAuth connection not found.")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    case Accounts.get_mcp_token(scope, id) do
      nil ->
        {:noreply,
         socket |> assign(:pending_delete, nil) |> put_flash(:error, "Token not found.")}

      token ->
        {:ok, _deleted} = Accounts.revoke_mcp_token(scope, token.id)
        tokens = Accounts.list_mcp_tokens(scope)
        oauth_connections = OAuth.list_connections(scope)

        {:noreply,
         socket
         |> put_flash(:info, "Token revoked.")
         |> assign(:tokens, tokens)
         |> assign(:oauth_connections, oauth_connections)
         |> assign(:tokens_empty?, tokens == [] and oauth_connections == [])
         |> assign(:pending_delete, nil)}
    end
  end

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
