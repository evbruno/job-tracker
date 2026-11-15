defmodule TrackMyJobEx.Repo.Migrations.CreateJobApplications do
  use Ecto.Migration

  # The statuses table is created here because job_applications references it
  # and SQLite cannot add foreign keys after the fact. The predefined status
  # rows are seeded by a later migration.
  def change do
    create table(:statuses) do
      add :slug, :string, null: false
      add :name, :string, null: false
      add :position, :integer, null: false
    end

    create unique_index(:statuses, [:slug])
    create unique_index(:statuses, [:position])

    create table(:job_applications) do
      add :position, :string, null: false
      add :description, :text
      add :job_posting_url, :text
      add :company_name, :string, null: false
      add :recruiter_name, :string
      add :status_id, references(:statuses, on_delete: :restrict), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end
  end
end
