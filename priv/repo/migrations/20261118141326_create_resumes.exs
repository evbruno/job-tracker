defmodule TrackMyJobEx.Repo.Migrations.CreateResumes do
  use Ecto.Migration

  def change do
    create table(:resumes) do
      add :title, :string, null: false
      add :body, :text, null: false
      add :email, :string, null: false
      add :full_name, :string
      add :headline, :string
      add :phone, :string
      add :location, :string
      add :linkedin_url, :text
      add :github_url, :text
      add :portfolio_url, :text
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:resumes, [:user_id, :updated_at])
    create index(:resumes, [:user_id, :inserted_at])

    create table(:resume_tags) do
      add :resume_id, references(:resumes, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false
    end

    create unique_index(:resume_tags, [:resume_id, :tag_id])
    create index(:resume_tags, [:tag_id, :resume_id])
  end
end
