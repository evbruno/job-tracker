defmodule TrackMyJobEx.Accounts.MCPToken do
  @moduledoc """
  A personal access token that authenticates an MCP client for one user.

  The plaintext token uses the shape `tmj_<prefix>_<secret>` and is shown only
  once, when the token is created. Only the SHA-256 hash of the full token and
  the public prefix are stored, so a database leak does not reveal usable
  credentials and a token can be looked up without scanning the table.

  Tokens are user-owned: creation, listing, and revocation go through scoped
  context functions. Verification is an authentication lookup that identifies
  the tenant, in the same category as the session-token lookup.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias __MODULE__

  @prefix "tmj_"
  @prefix_bytes 9
  @secret_bytes 32
  @max_name 100

  # `last_used_at` is written at most once per interval so a busy client does
  # not turn every read into a SQLite write.
  @last_used_interval_seconds 5 * 60

  schema "mcp_tokens" do
    field :name, :string
    field :token_prefix, :string
    field :token_hash, :binary
    field :last_used_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :user, TrackMyJobEx.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Generates a token, returning `{plaintext, prefix, hash}`.

  The plaintext is never persisted; only the prefix and hash are.
  """
  def generate do
    prefix = Base.encode32(:crypto.strong_rand_bytes(@prefix_bytes), case: :lower, padding: false)
    secret = Base.url_encode64(:crypto.strong_rand_bytes(@secret_bytes), padding: false)
    plaintext = @prefix <> prefix <> "_" <> secret

    {plaintext, prefix, hash(plaintext)}
  end

  @doc """
  Hashes a full plaintext token with SHA-256.
  """
  def hash(token) when is_binary(token) do
    :crypto.hash(:sha256, token)
  end

  @doc """
  Extracts the public prefix from a plaintext token.

  Returns `:error` for anything that is not shaped like an MCP token.
  """
  def prefix_from_token(@prefix <> rest) do
    case String.split(rest, "_", parts: 2) do
      [prefix, secret] when byte_size(prefix) > 0 and byte_size(secret) > 0 -> {:ok, prefix}
      _other -> :error
    end
  end

  def prefix_from_token(_other), do: :error

  @doc """
  Compares the stored hash with the hash of a presented token in constant time.
  """
  def valid_hash?(%MCPToken{token_hash: stored}, token)
      when is_binary(stored) and is_binary(token) do
    Plug.Crypto.secure_compare(stored, hash(token))
  end

  def valid_hash?(_token, _presented), do: false

  @doc """
  Returns true when the token has an expiry that is not in the future.
  """
  def expired?(%MCPToken{expires_at: nil}), do: false

  def expired?(%MCPToken{expires_at: %DateTime{} = expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now(:second)) != :gt
  end

  @doc """
  Returns true when `last_used_at` should be refreshed for this request.
  """
  def last_used_stale?(%MCPToken{last_used_at: nil}), do: true

  def last_used_stale?(%MCPToken{last_used_at: %DateTime{} = last_used_at}) do
    DateTime.diff(DateTime.utc_now(:second), last_used_at, :second) >= @last_used_interval_seconds
  end

  @doc """
  Builds a changeset for a new token.

  `token_prefix` and `token_hash` are set programmatically by the context and
  are never cast from caller input.
  """
  def creation_changeset(token \\ %MCPToken{}, attrs) do
    token
    |> cast(attrs, [:name, :expires_at])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name])
    |> validate_length(:name, max: @max_name)
    |> validate_expiry()
  end

  defp validate_expiry(changeset) do
    case get_change(changeset, :expires_at) do
      %DateTime{} = expires_at ->
        if DateTime.compare(expires_at, DateTime.utc_now(:second)) == :gt do
          changeset
        else
          add_error(changeset, :expires_at, "must be in the future")
        end

      _other ->
        changeset
    end
  end
end
