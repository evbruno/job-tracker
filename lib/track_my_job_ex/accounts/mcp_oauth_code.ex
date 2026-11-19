defmodule TrackMyJobEx.Accounts.MCPOAuthCode do
  @moduledoc false
  use Ecto.Schema

  schema "mcp_oauth_codes" do
    field :code_hash, :binary
    field :client_id, :string
    field :user_id, :integer
    field :redirect_uri, :string
    field :code_challenge, :string
    field :scope, :string
    field :resource, :string
    field :expires_at, :utc_datetime
    field :consumed_at, :utc_datetime
    timestamps(type: :utc_datetime, updated_at: false)
  end
end
