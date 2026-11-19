defmodule TrackMyJobEx.Repo.Migrations.AddStartDateArchivedAndGhostedStatus do
  use Ecto.Migration

  def change do
    alter table(:job_applications) do
      add :start_date, :date
      add :archived_at, :utc_datetime
    end

    create index(:job_applications, [:user_id, :archived_at])

    execute(
      "INSERT INTO statuses (slug, name, position) VALUES ('ghosted', 'Ghosted', 14)",
      "DELETE FROM statuses WHERE slug = 'ghosted'"
    )
  end
end
