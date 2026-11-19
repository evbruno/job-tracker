defmodule TrackMyJobEx.JobApplications.ApplicationTag do
  @moduledoc """
  Join row linking an application to a tag.

  Both foreign keys cascade on delete: removing an application removes its tag
  links, and removing a tag removes its links without touching applications.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "application_tags" do
    belongs_to :application, TrackMyJobEx.JobApplications.JobApplication
    belongs_to :tag, TrackMyJobEx.Tags.Tag
  end

  @doc false
  def changeset(application_tag, attrs) do
    application_tag
    |> cast(attrs, [:application_id, :tag_id])
    |> validate_required([:application_id, :tag_id])
    |> unique_constraint([:application_id, :tag_id],
      name: :application_tags_application_id_tag_id_index
    )
  end
end
