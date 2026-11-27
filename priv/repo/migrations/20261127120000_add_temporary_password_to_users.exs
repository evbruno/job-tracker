defmodule TrackMyJobEx.Repo.Migrations.AddTemporaryPasswordToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :temporary_password, :boolean, default: false, null: false
    end
  end
end
