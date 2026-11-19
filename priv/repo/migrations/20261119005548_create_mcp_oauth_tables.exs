defmodule TrackMyJobEx.Repo.Migrations.CreateMcpOauthTables do
  use Ecto.Migration

  def change do
    create table(:mcp_oauth_clients) do
      add :client_id, :string, null: false
      add :client_name, :string, null: false
      add :redirect_uris, :map, null: false
      add :token_endpoint_auth_method, :string, null: false, default: "none"
      timestamps(type: :utc_datetime)
    end

    create unique_index(:mcp_oauth_clients, [:client_id])

    create table(:mcp_oauth_codes) do
      add :code_hash, :binary, null: false

      add :client_id,
          references(:mcp_oauth_clients,
            column: :client_id,
            type: :string,
            on_delete: :delete_all
          ),
          null: false

      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :redirect_uri, :text, null: false
      add :code_challenge, :string, null: false
      add :scope, :string, null: false
      add :resource, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :consumed_at, :utc_datetime
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:mcp_oauth_codes, [:code_hash])
    create index(:mcp_oauth_codes, [:expires_at])

    create table(:mcp_oauth_tokens) do
      add :token_hash, :binary, null: false
      add :token_type, :string, null: false

      add :client_id,
          references(:mcp_oauth_clients,
            column: :client_id,
            type: :string,
            on_delete: :delete_all
          ),
          null: false

      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :family_id, :string, null: false
      add :scope, :string, null: false
      add :resource, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :revoked_at, :utc_datetime
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:mcp_oauth_tokens, [:token_hash])
    create index(:mcp_oauth_tokens, [:family_id, :token_type])
    create index(:mcp_oauth_tokens, [:expires_at])
  end
end
