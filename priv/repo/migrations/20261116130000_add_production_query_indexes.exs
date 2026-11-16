defmodule TrackMyJobEx.Repo.Migrations.AddProductionQueryIndexes do
  use Ecto.Migration

  # Composite indexes matching the Phase 5/6 access patterns. SQLite can use a
  # leading `user_id` equality predicate and then satisfy the remaining
  # equality/order-by columns from the same index.
  #
  # `(user_id, company_name)` already exists from an earlier migration. The
  # NOCASE variants let the case-insensitive exact-match filters use an index
  # instead of scanning all of the user's rows.
  def change do
    create index(:job_applications, [:user_id, :status_id])
    create index(:job_applications, [:user_id, :recruiter_name])
    create index(:job_applications, [:user_id, :inserted_at])
    create index(:job_applications, [:user_id, :updated_at])

    execute(
      """
      CREATE INDEX job_applications_user_id_company_name_nocase_index
      ON job_applications (user_id, company_name COLLATE NOCASE)
      """,
      "DROP INDEX IF EXISTS job_applications_user_id_company_name_nocase_index"
    )

    execute(
      """
      CREATE INDEX job_applications_user_id_recruiter_name_nocase_index
      ON job_applications (user_id, recruiter_name COLLATE NOCASE)
      """,
      "DROP INDEX IF EXISTS job_applications_user_id_recruiter_name_nocase_index"
    )

    create index(:application_status_histories, [:application_id, :changed_at])
    create index(:application_tags, [:tag_id, :application_id])
  end
end
