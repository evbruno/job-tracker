defmodule TrackMyJobEx.Tags.Tag do
  @moduledoc """
  A user-owned tag used to categorize job applications.

  Names are trimmed, limited to 50 characters, and unique per user in a
  case-insensitive way while preserving the casing the user entered.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @max_name 50

  schema "tags" do
    field :name, :string

    belongs_to :user, TrackMyJobEx.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for creating or renaming a tag.

  `user_id` is set programmatically by the context and is never cast from
  client input.
  """
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name])
    |> validate_length(:name, max: @max_name)
    |> unique_constraint(:name, name: :tags_user_id_name_index)
  end
end
