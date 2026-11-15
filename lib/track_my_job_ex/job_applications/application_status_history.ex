defmodule TrackMyJobEx.JobApplications.ApplicationStatusHistory do
  @moduledoc """
  An append-only record of an application status change.

  History rows are never updated or deleted individually. They are removed only
  when the parent application is deleted (database cascade).

  Creating the initial Interested record and subsequent status transitions is
  implemented in Phase 5.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @max_notes 2_000

  schema "application_status_histories" do
    field :previous_status_id, :id
    field :new_status_id, :id
    field :changed_at, :utc_datetime
    field :notes, :string

    belongs_to :application, TrackMyJobEx.JobApplications.JobApplication
  end

  @doc """
  Builds a changeset for a status history record.

  The application is assigned programmatically by the context, never cast from
  client input.
  """
  def changeset(status_history, attrs) do
    status_history
    |> cast(attrs, [:previous_status_id, :new_status_id, :changed_at, :notes])
    |> validate_required([:new_status_id, :changed_at])
    |> validate_length(:notes, max: @max_notes)
  end
end
