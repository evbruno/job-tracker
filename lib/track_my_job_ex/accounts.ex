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

  ## User provisioning

  @doc """
  Provisions a user with an email and password.

  This is the only way to create users. Public registration is disabled.
  """
  def create_user(attrs) do
    %User{}
    |> User.creation_changeset(attrs)
    |> Repo.insert()
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
    case get_mcp_token(scope, id) do
      nil -> {:error, :not_found}
      token -> Repo.delete(token)
    end
  end

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
