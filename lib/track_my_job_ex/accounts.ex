defmodule TrackMyJobEx.Accounts do
  @moduledoc """
  The Accounts context.

  Users are provisioned by an administrator through the `mix users.create`
  task. There is no public registration. Authentication lookups are intentionally
  global because the user is the tenant being identified; user-owned domain
  data must be queried through scoped context functions instead.
  """

  import Ecto.Query, warn: false
  alias TrackMyJobEx.Repo

  alias TrackMyJobEx.Accounts.{MCPToken, Scope, User, UserToken}

  ## Database getters

  @doc """
  Gets a user by email.

  Email comparisons are case-insensitive because the users table uses
  `COLLATE NOCASE` on the email column.
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  Returns `nil` when the email is unknown or the password is invalid.
  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  def change_temporary_password(email, current_password, new_password)
      when is_binary(email) and is_binary(current_password) and is_binary(new_password) do
    case get_user_by_email_and_password(email, current_password) do
      %User{temporary_password: true} = user ->
        user
        |> User.password_changeset(%{"password" => new_password})
        |> Repo.update()

      _ ->
        {:error, :invalid_current_password}
    end
  end

  ## User provisioning

  @doc """
  Provisions a user with an email and password.

  This is the only way to create users. Public registration is disabled.
  """
  def create_user(attrs) when is_map(attrs) do
    is_admin = truthy_attr?(attrs, :is_admin)
    temporary_password = truthy_attr?(attrs, :temporary_password)

    attrs = attrs |> drop_attr(:is_admin) |> drop_attr(:temporary_password)

    %User{is_admin: is_admin, temporary_password: temporary_password}
    |> User.creation_changeset(attrs)
    |> Repo.insert()
  end

  defp truthy_attr?(attrs, key) when is_map(attrs) do
    value =
      case Map.get(attrs, key) do
        nil -> Map.get(attrs, Atom.to_string(key))
        v -> v
      end

    value in [true, "true", 1, "1", "on"]
  end

  defp drop_attr(attrs, key) when is_map(attrs) do
    attrs
    |> Map.delete(key)
    |> Map.delete(Atom.to_string(key))
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## MCP personal access tokens

  @doc """
  Creates an MCP token for the scope's user.

  Returns `{:ok, token, plaintext}`. The plaintext is the only time the usable
  credential exists; only the prefix and a SHA-256 hash are stored.

  `user_id` is derived from the scope and is never accepted from the caller.
  """
  def create_mcp_token(%Scope{user: %User{} = user}, attrs) when is_map(attrs) do
    {plaintext, prefix, token_hash} = MCPToken.generate()

    %MCPToken{user_id: user.id, token_prefix: prefix, token_hash: token_hash}
    |> MCPToken.creation_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, token} -> {:ok, token, plaintext}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Lists the scope's MCP tokens, newest first.

  Only the owner's tokens are returned; the plaintext is never available.
  """
  def list_mcp_tokens(%Scope{user: %User{id: user_id}}) do
    from(token in MCPToken,
      where: token.user_id == ^user_id,
      order_by: [desc: token.inserted_at, desc: token.id]
    )
    |> Repo.all()
  end

  @doc """
  Gets one of the scope's MCP tokens, or `nil`.

  Another user's token id returns `nil`.
  """
  def get_mcp_token(%Scope{user: %User{id: user_id}}, id) do
    case Ecto.Type.cast(:id, id) do
      {:ok, id} ->
        Repo.one(
          from(token in MCPToken,
            where: token.id == ^id and token.user_id == ^user_id
          )
        )

      :error ->
        nil
    end
  end

  @doc """
  Revokes one of the scope's MCP tokens by hard-deleting it.

  Returns `{:ok, token}` or `{:error, :not_found}`. Another user's token
  behaves as not found.
  """
  def revoke_mcp_token(%Scope{} = scope, id) do
    token =
      if Scope.admin?(scope) do
        case Ecto.Type.cast(:id, id) do
          {:ok, id} -> Repo.get(MCPToken, id)
          :error -> nil
        end
      else
        get_mcp_token(scope, id)
      end

    case token do
      nil -> {:error, :not_found}
      token -> Repo.delete(token)
    end
  end

  @doc """
  Returns true when the scope belongs to an administrator.
  """
  def admin?(%Scope{} = scope), do: Scope.admin?(scope)

  @doc """
  Lists every user. Administrators only.

  Returns `{:ok, users}` or `{:error, :unauthorized}`.
  """
  def list_users(%Scope{user: %{is_admin: true}}) do
    users =
      from(user in User, order_by: [asc: user.email, asc: user.id])
      |> Repo.all()

    {:ok, users}
  end

  def list_users(%Scope{}), do: {:error, :unauthorized}

  @doc """
  Creates a user. Administrators only.

  Returns `{:ok, user}` or `{:error, :unauthorized}` / `{:error, changeset}`.
  """
  def create_user(%Scope{user: %{is_admin: true}}, attrs) when is_map(attrs) do
    create_user(attrs)
  end

  def create_user(%Scope{}, _attrs), do: {:error, :unauthorized}

  @doc """
  Deletes a user. Administrators only; a user cannot delete themselves.

  Returns `{:ok, user}`, `{:error, :unauthorized}`, or `{:error, :cannot_delete_self}`.
  """
  def delete_user(%Scope{user: %{is_admin: true, id: admin_id}}, user_id) do
    case Ecto.Type.cast(:id, user_id) do
      {:ok, id} when id == admin_id ->
        {:error, :cannot_delete_self}

      {:ok, id} ->
        case Repo.get(User, id) do
          nil -> {:error, :not_found}
          user -> Repo.delete(user)
        end

      :error ->
        {:error, :not_found}
    end
  end

  def delete_user(%Scope{}, _user_id), do: {:error, :unauthorized}

  @doc """
  Sets or clears the admin flag on a user. Administrators only.

  Returns `{:ok, user}`, `{:error, :unauthorized}`, or `{:error, :not_found}`.
  """
  def set_user_admin(%Scope{user: %{is_admin: true}}, user_id, is_admin)
      when is_boolean(is_admin) do
    case Ecto.Type.cast(:id, user_id) do
      {:ok, id} ->
        case Repo.get(User, id) do
          nil -> {:error, :not_found}
          user -> user |> Ecto.Changeset.change(is_admin: is_admin) |> Repo.update()
        end

      :error ->
        {:error, :not_found}
    end
  end

  def set_user_admin(%Scope{}, _user_id, _is_admin), do: {:error, :unauthorized}

  def set_user_temporary_password(%Scope{user: %{is_admin: true}}, user_id, temporary?)
      when is_boolean(temporary?) do
    case Ecto.Type.cast(:id, user_id) do
      {:ok, id} ->
        case Repo.get(User, id) do
          nil -> {:error, :not_found}
          user -> user |> Ecto.Changeset.change(temporary_password: temporary?) |> Repo.update()
        end

      :error ->
        {:error, :not_found}
    end
  end

  def set_user_temporary_password(%Scope{}, _user_id, _temporary?), do: {:error, :unauthorized}

  ## MCP personal access tokens (admin)

  @doc """
  Lists every MCP token. Administrators only.

  Returns `{:ok, tokens}` (with the owning user preloaded) or
  `{:error, :unauthorized}`.
  """
  def list_all_mcp_tokens(%Scope{user: %{is_admin: true}}) do
    tokens =
      from(token in MCPToken,
        order_by: [desc: token.inserted_at, desc: token.id],
        preload: [:user]
      )
      |> Repo.all()

    {:ok, tokens}
  end

  def list_all_mcp_tokens(%Scope{}), do: {:error, :unauthorized}

  @doc """
  Creates an MCP token for the given user. Administrators only.

  Returns `{:ok, token, plaintext}` or `{:error, :unauthorized}` / `{:error, changeset}`.
  """
  def create_mcp_token_for_user(%Scope{user: %{is_admin: true}}, user_id, attrs)
      when is_map(attrs) do
    with {:ok, id} <- Ecto.Type.cast(:id, user_id),
         %User{} = user <- Repo.get(User, id) do
      create_mcp_token(Scope.for_user(user), attrs)
    else
      _other -> {:error, :not_found}
    end
  end

  def create_mcp_token_for_user(%Scope{}, _user_id, _attrs), do: {:error, :unauthorized}

  @doc """
  Authenticates a plaintext MCP token and returns `{:ok, user, token}`.

  This is an authentication lookup that identifies the tenant, in the same
  category as the session-token lookup. It is global by design and must not be
  reused to decide ownership of domain data; callers must derive a `Scope` from
  the returned user.

  Unknown, malformed, revoked, and expired tokens all return `:error` so the
  response does not reveal which case occurred. Successful use refreshes
  `last_used_at` at most once every five minutes.
  """
  def get_user_by_mcp_token(token) when is_binary(token) do
    with {:ok, prefix} <- MCPToken.prefix_from_token(token),
         %MCPToken{} = mcp_token <- Repo.get_by(MCPToken, token_prefix: prefix),
         true <- MCPToken.valid_hash?(mcp_token, token),
         false <- MCPToken.expired?(mcp_token),
         %User{} = user <- Repo.get(User, mcp_token.user_id) do
      touch_mcp_token(mcp_token)
      {:ok, user, mcp_token}
    else
      _other -> :error
    end
  end

  def get_user_by_mcp_token(_token), do: :error

  defp touch_mcp_token(%MCPToken{} = token) do
    if MCPToken.last_used_stale?(token) do
      now = DateTime.utc_now(:second)

      from(t in MCPToken, where: t.id == ^token.id)
      |> Repo.update_all(set: [last_used_at: now])
    end

    :ok
  end
end
