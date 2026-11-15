defmodule TrackMyJobEx.Repo.Migrations.AddDomainIndexes do
  use Ecto.Migration

  def change do
    create unique_index(:application_tags, [:application_id, :tag_id])
    create index(:application_tags, [:tag_id])

    create index(:application_status_histories, [:application_id])
    create index(:application_status_histories, [:new_status_id])
    create index(:application_status_histories, [:previous_status_id])

    create index(:job_applications, [:status_id])
    create index(:tags, [:user_id])
  end
end
