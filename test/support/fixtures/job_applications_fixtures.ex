defmodule TrackMyJobEx.JobApplicationsFixtures do
  @moduledoc """
  Test helpers for creating job applications and status history rows.
  """

  alias TrackMyJobEx.Accounts.Scope
  alias TrackMyJobEx.JobApplications
  alias TrackMyJobEx.JobApplications.ApplicationStatusHistory
  alias TrackMyJobEx.Repo

  def valid_application_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      position: "Senior Engineer",
      description: "Build and maintain the platform.",
      job_posting_url: "https://example.com/jobs/senior-engineer",
      company_name: "Acme Corp",
      recruiter_name: "Jane Recruiter"
    })
  end

  def application_fixture(%Scope{} = scope, attrs \\ %{}) do
    {:ok, application} =
      scope
      |> JobApplications.create_application(valid_application_attributes(attrs))

    application
  end

  def status_history_fixture(application, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        new_status_id: JobApplications.default_status().id,
        changed_at: DateTime.utc_now(:second)
      })

    %ApplicationStatusHistory{application_id: application.id}
    |> ApplicationStatusHistory.changeset(attrs)
    |> Repo.insert!()
  end
end
