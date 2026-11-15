defmodule TrackMyJobEx.Repo.Migrations.AddTagNameUniqueIndex do
  use Ecto.Migration

  # Ecto cannot express a NOCASE collation on an index column, so this uses
  # raw SQL. The index name follows Ecto's convention for the tags table so
  # `unique_constraint(:name, name: :tags_user_id_name_index)` can match the
  # constraint reported by the SQLite adapter.
  def up do
    execute("CREATE UNIQUE INDEX tags_user_id_name_index ON tags (user_id, name COLLATE NOCASE)")
  end

  def down do
    execute("DROP INDEX IF EXISTS tags_user_id_name_index")
  end
end
