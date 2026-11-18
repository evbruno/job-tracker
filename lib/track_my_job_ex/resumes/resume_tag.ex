defmodule TrackMyJobEx.Resumes.ResumeTag do
  @moduledoc """
  Join row linking a resume to a tag.

  Both foreign keys cascade on delete: removing a resume removes its tag links,
  and removing a tag removes its links without touching resumes.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "resume_tags" do
    belongs_to :resume, TrackMyJobEx.Resumes.Resume
    belongs_to :tag, TrackMyJobEx.Tags.Tag
  end

  @doc false
  def changeset(resume_tag, attrs) do
    resume_tag
    |> cast(attrs, [:resume_id, :tag_id])
    |> validate_required([:resume_id, :tag_id])
    |> unique_constraint([:resume_id, :tag_id],
      name: :resume_tags_resume_id_tag_id_index
    )
  end
end
