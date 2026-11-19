defmodule TrackMyJobEx.Dashboard do
  @moduledoc "Tenant-scoped summary metrics for the dashboard."

  import Ecto.Query

  alias TrackMyJobEx.Accounts.{Scope, User}
  alias TrackMyJobEx.JobApplications.{JobApplication, Status}
  alias TrackMyJobEx.Repo
  alias TrackMyJobEx.Resumes.Resume
  alias TrackMyJobEx.Tags.Tag

  @in_progress_statuses ~w(interested applied screening interview technical_interview final_interview offer accepted on_hold)

  @doc "Returns counts of records owned by the current user."
  def counts(%Scope{user: %User{id: user_id}}) do
    %{
      applications: count_owned(JobApplication, user_id),
      tags: count_owned(Tag, user_id),
      resumes: count_owned(Resume, user_id),
      in_progress_applications: count_in_progress_applications(user_id)
    }
  end

  def counts(_scope) do
    %{applications: 0, tags: 0, resumes: 0, in_progress_applications: 0}
  end

  defp count_owned(schema, user_id) do
    Repo.aggregate(from(record in schema, where: record.user_id == ^user_id), :count, :id)
  end

  defp count_in_progress_applications(user_id) do
    Repo.aggregate(
      from(application in JobApplication,
        join: status in Status,
        on: status.id == application.status_id,
        where: application.user_id == ^user_id,
        where: is_nil(application.archived_at),
        where: status.slug in ^@in_progress_statuses
      ),
      :count,
      :id
    )
  end
end
