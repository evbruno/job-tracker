defmodule TrackMyJobEx.Repo.Migrations.RemoveUnusedAuthColumns do
  use Ecto.Migration

  def up do
    alter table(:users) do
      remove :confirmed_at
    end

    alter table(:users_tokens) do
      remove :sent_to
    end
  end

  def down do
    alter table(:users) do
      add :confirmed_at, :utc_datetime
    end

    alter table(:users_tokens) do
      add :sent_to, :string
    end
  end
end
