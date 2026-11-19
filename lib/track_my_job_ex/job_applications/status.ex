defmodule TrackMyJobEx.JobApplications.Status do
  @moduledoc """
  A predefined application status shared by every user.

  Statuses are seeded by a migration and are read-only. Users cannot create or
  customize them. They are referenced by applications and status history rows.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "statuses" do
    field :slug, :string
    field :name, :string
    field :position, :integer
  end

  @doc false
  def changeset(status, attrs) do
    status
    |> cast(attrs, [:slug, :name, :position])
    |> validate_required([:slug, :name, :position])
    |> unique_constraint(:slug)
    |> unique_constraint(:position)
  end
end
