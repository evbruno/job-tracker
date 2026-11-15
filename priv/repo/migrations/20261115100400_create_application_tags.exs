defmodule TrackMyJobEx.Repo.Migrations.CreateApplicationTags do
  use Ecto.Migration

  def change do
    create table(:application_tags) do
      add :application_id, references(:job_applications, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false
    end
  end
end
