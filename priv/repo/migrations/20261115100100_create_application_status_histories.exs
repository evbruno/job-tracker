defmodule TrackMyJobEx.Repo.Migrations.CreateApplicationStatusHistories do
  use Ecto.Migration

  def change do
    create table(:application_status_histories) do
      add :application_id, references(:job_applications, on_delete: :delete_all), null: false
      add :previous_status_id, references(:statuses, on_delete: :restrict)
      add :new_status_id, references(:statuses, on_delete: :restrict), null: false
      add :changed_at, :utc_datetime, null: false
      add :notes, :text
    end
  end
end
