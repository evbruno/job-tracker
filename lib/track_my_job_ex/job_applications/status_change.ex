defmodule TrackMyJobEx.JobApplications.StatusChange do
  @moduledoc """
  A form-only representation of a requested application status change.

  It is not persisted. The context validates the requested status and notes
  through this schema and then updates the application and inserts an
  `ApplicationStatusHistory` row in one transaction.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @max_notes 2_000

  @primary_key false
  embedded_schema do
    field :status_id, :integer
    field :notes, :string
  end

  @doc """
  Builds a changeset for a requested status change.

  `notes` is trimmed and a blank value is stored as `nil`.
  """
  def changeset(status_change \\ %__MODULE__{}, attrs) do
    status_change
    |> cast(attrs, [:status_id, :notes])
    |> normalize_notes()
    |> validate_required([:status_id])
    |> validate_length(:notes, max: @max_notes)
  end

  @doc """
  Returns the maximum allowed length for status change notes.
  """
  def max_notes, do: @max_notes

  defp normalize_notes(changeset) do
    case get_change(changeset, :notes) do
      notes when is_binary(notes) ->
        changeset
        |> put_change(:notes, String.trim(notes))
        |> blank_to_nil(:notes)

      _ ->
        changeset
    end
  end

  defp blank_to_nil(changeset, field) do
    if get_change(changeset, field) == "" do
      put_change(changeset, field, nil)
    else
      changeset
    end
  end
end
