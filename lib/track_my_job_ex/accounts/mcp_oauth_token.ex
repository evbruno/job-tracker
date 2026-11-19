defmodule TrackMyJobEx.Accounts.MCPOAuthToken do
  @moduledoc false
  use Ecto.Schema

  schema "mcp_oauth_tokens" do
    field :token_hash, :binary
    field :token_type, :string
    field :client_id, :string
    field :user_id, :integer
    field :family_id, :string
    field :scope, :string
    field :resource, :string
    field :expires_at, :utc_datetime
    field :revoked_at, :utc_datetime
    timestamps(type: :utc_datetime, updated_at: false)
  end
end
