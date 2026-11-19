defmodule TrackMyJobEx.Repo.Migrations.AddBudgetToJobApplications do
  use Ecto.Migration

  def change do
    alter table(:job_applications) do
      add :budget_min, :integer
      add :budget_max, :integer
    end
  end
end
