defmodule TrackMyJobEx.Repo.Migrations.AddUserCompanyNameIndex do
  use Ecto.Migration

  def change do
    create index(:job_applications, [:user_id, :company_name])
  end
end
