defmodule TrackMyJobEx.MCP.OAuth do
  @moduledoc """
  OAuth state and opaque token management for the MCP authorization server.

  OAuth credentials are stored only as SHA-256 hashes. Authorization codes are
  single-use and bound to their client, redirect URI, PKCE challenge, scope, and
  resource. Access tokens are resource-bound and short-lived; refresh tokens are
  single-use and rotated on redemption.
  """

  import Ecto.Query

  alias TrackMyJobEx.Accounts.{MCPOAuthClient, MCPOAuthCode, MCPOAuthToken, User}
  alias TrackMyJobEx.Repo

  @scope "job-tracker"
  @code_ttl_seconds 300
  @access_ttl_seconds 600
  @refresh_ttl_seconds 30 * 24 * 60 * 60

  def scope, do: @scope
  def access_ttl, do: @access_ttl_seconds

  def resource_url do
    Application.get_env(:track_my_job_ex, :mcp_resource_url)
  end

  def issuer_url do
    Application.get_env(:track_my_job_ex, :mcp_oauth_issuer_url)
  end

  def register_client(attrs) when is_map(attrs) do
    redirect_uris = attrs["redirect_uris"]
    client_name = attrs["client_name"]

    with true <- is_binary(client_name) and String.trim(client_name) != "",
         true <- is_list(redirect_uris) and redirect_uris != [],
         true <- Enum.all?(redirect_uris, &is_binary/1) do
      client_id = "tmj_client_" <> random_token(24)

      %MCPOAuthClient{}
      |> MCPOAuthClient.changeset(%{
        client_id: client_id,
        client_name: String.trim(client_name),
        redirect_uris: Enum.uniq(redirect_uris),
        token_endpoint_auth_method: "none"
      })
      |> Repo.insert()
      |> case do
        {:ok, client} -> {:ok, client}
        error -> error
      end
    else
      _ -> {:error, :invalid_client_metadata}
    end
  end

  def get_client(client_id) when is_binary(client_id),
    do: Repo.get_by(MCPOAuthClient, client_id: client_id)

  def get_client(_client_id), do: nil

  def create_authorization_code(attrs) do
    code = random_token(32)
    now = DateTime.utc_now(:second)

    %MCPOAuthCode{
      code_hash: hash(code),
      client_id: attrs.client_id,
      user_id: attrs.user_id,
      redirect_uri: attrs.redirect_uri,
      code_challenge: attrs.code_challenge,
      scope: @scope,
      resource: attrs.resource,
      expires_at: DateTime.add(now, @code_ttl_seconds, :second)
    }
    |> Repo.insert()
    |> case do
      {:ok, _record} -> {:ok, code}
      error -> error
    end
  end

  def exchange_code(attrs) do
    if valid_exchange_attrs?(attrs) do
      exchange_valid_code(attrs)
    else
      {:error, :invalid_grant}
    end
  end

  defp exchange_valid_code(attrs) do
    now = DateTime.utc_now(:second)

    Repo.transaction(fn ->
      code = fetch_authorization_code(attrs, now)
      validate_authorization_code!(code, attrs)
      consume_authorization_code!(code, now)
      user = Repo.get!(User, code.user_id)
      issue_token_pair(user.id, code.client_id, code.scope, code.resource, random_token(18), now)
    end)
    |> case do
      {:ok, token_pair} -> {:ok, token_pair}
      {:error, reason} -> {:error, reason}
    end
  end

  def refresh_tokens(attrs) do
    if valid_refresh_attrs?(attrs) do
      refresh_valid_token(attrs)
    else
      {:error, :invalid_grant}
    end
  end

  defp refresh_valid_token(attrs) do
    now = DateTime.utc_now(:second)

    Repo.transaction(fn ->
      token = fetch_refresh_token(attrs, now)
      validate_refresh_token!(token, attrs)
      revoke_refresh_token!(token, now)

      issue_token_pair(
        token.user_id,
        token.client_id,
        token.scope,
        token.resource,
        token.family_id,
        now
      )
    end)
    |> case do
      {:ok, token_pair} -> {:ok, token_pair}
      {:error, reason} -> {:error, reason}
    end
  end

  defp valid_exchange_attrs?(attrs) do
    Enum.all?(
      [
        attrs[:code],
        attrs[:client_id],
        attrs[:redirect_uri],
        attrs[:code_verifier],
        attrs[:resource]
      ],
      &is_binary/1
    )
  end

  defp valid_refresh_attrs?(attrs) do
    Enum.all?([attrs[:refresh_token], attrs[:client_id], attrs[:resource]], &is_binary/1)
  end

  defp fetch_authorization_code(attrs, now) do
    code_hash = hash(attrs.code)

    Repo.one(
      from(c in MCPOAuthCode,
        where:
          c.code_hash == ^code_hash and c.client_id == ^attrs.client_id and
            c.redirect_uri == ^attrs.redirect_uri and is_nil(c.consumed_at) and
            c.expires_at > ^now
      )
    )
  end

  defp validate_authorization_code!(code, attrs) do
    challenge = pkce_challenge(attrs.code_verifier)

    unless code && Plug.Crypto.secure_compare(code.code_challenge, challenge) &&
             code.resource == attrs.resource do
      Repo.rollback(:invalid_grant)
    end
  end

  defp consume_authorization_code!(code, now) do
    case Repo.update_all(
           from(c in MCPOAuthCode, where: c.id == ^code.id and is_nil(c.consumed_at)),
           set: [consumed_at: now]
         ) do
      {1, _} -> :ok
      _ -> Repo.rollback(:invalid_grant)
    end
  end

  defp fetch_refresh_token(attrs, now) do
    token_hash = hash(attrs.refresh_token)

    Repo.one(
      from(t in MCPOAuthToken,
        where:
          t.token_hash == ^token_hash and t.token_type == "refresh" and
            t.client_id == ^attrs.client_id and is_nil(t.revoked_at) and
            t.expires_at > ^now
      )
    )
  end

  defp validate_refresh_token!(token, attrs) do
    unless token && token.resource == attrs.resource, do: Repo.rollback(:invalid_grant)
  end

  defp revoke_refresh_token!(token, now) do
    case Repo.update_all(
           from(t in MCPOAuthToken, where: t.id == ^token.id and is_nil(t.revoked_at)),
           set: [revoked_at: now]
         ) do
      {1, _} -> :ok
      _ -> Repo.rollback(:invalid_grant)
    end
  end

  def authenticate_access_token(token, resource) when is_binary(token) do
    now = DateTime.utc_now(:second)
    token_hash = hash(token)

    record =
      Repo.one(
        from(t in MCPOAuthToken,
          where:
            t.token_hash == ^token_hash and t.token_type == "access" and
              is_nil(t.revoked_at) and t.expires_at > ^now and t.resource == ^resource
        )
      )

    case record && Repo.get(User, record.user_id) do
      %User{} = user -> {:ok, user, record.scope}
      _other -> :error
    end
  end

  def authenticate_access_token(_token, _resource), do: :error

  def revoke_token(token) when is_binary(token) do
    now = DateTime.utc_now(:second)
    token_hash = hash(token)

    case Repo.get_by(MCPOAuthToken, token_hash: token_hash) do
      nil ->
        :ok

      %MCPOAuthToken{token_type: "refresh", family_id: family_id} ->
        Repo.update_all(
          from(t in MCPOAuthToken, where: t.family_id == ^family_id and is_nil(t.revoked_at)),
          set: [revoked_at: now]
        )

        :ok

      %MCPOAuthToken{} = record ->
        Repo.update_all(
          from(t in MCPOAuthToken, where: t.id == ^record.id and is_nil(t.revoked_at)),
          set: [revoked_at: now]
        )

        :ok
    end
  end

  def revoke_token(_token), do: :ok

  def valid_pkce_challenge?(challenge) when is_binary(challenge) do
    byte_size(challenge) == 43 and Regex.match?(~r/^[A-Za-z0-9_-]+$/, challenge)
  end

  def valid_pkce_challenge?(_challenge), do: false

  def pkce_challenge(verifier) when is_binary(verifier) do
    :crypto.hash(:sha256, verifier)
    |> Base.url_encode64(padding: false)
  end

  defp issue_token_pair(user_id, client_id, scope, resource, family_id, now) do
    access_token = random_token(32)
    refresh_token = random_token(48)

    Repo.insert!(%MCPOAuthToken{
      token_hash: hash(access_token),
      token_type: "access",
      client_id: client_id,
      user_id: user_id,
      family_id: family_id,
      scope: scope,
      resource: resource,
      expires_at: DateTime.add(now, @access_ttl_seconds, :second)
    })

    Repo.insert!(%MCPOAuthToken{
      token_hash: hash(refresh_token),
      token_type: "refresh",
      client_id: client_id,
      user_id: user_id,
      family_id: family_id,
      scope: scope,
      resource: resource,
      expires_at: DateTime.add(now, @refresh_ttl_seconds, :second)
    })

    %{
      access_token: access_token,
      refresh_token: refresh_token,
      expires_in: @access_ttl_seconds,
      scope: scope
    }
  end

  defp random_token(bytes),
    do: Base.url_encode64(:crypto.strong_rand_bytes(bytes), padding: false)

  defp hash(value), do: :crypto.hash(:sha256, value)
end
