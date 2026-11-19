defmodule TrackMyJobEx.Repo.Migrations.CreateMcpTokens do
  use Ecto.Migration

  def change do
    create table(:mcp_tokens) do
      add :name, :string, null: false
      add :token_prefix, :string, null: false
      add :token_hash, :binary, null: false
      add :last_used_at, :utc_datetime
      add :expires_at, :utc_datetime
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    # Tokens are looked up by their public prefix; the unique index also
    # guarantees that a prefix resolves to at most one token.
    create unique_index(:mcp_tokens, [:token_prefix])
    create index(:mcp_tokens, [:user_id, :inserted_at])
  end
end
