defmodule TrackMyJobEx.ResumesFixtures do
  @moduledoc """
  Test helpers for creating resumes.
  """

  alias TrackMyJobEx.Accounts.Scope
  alias TrackMyJobEx.Resumes

  def valid_resume_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      title: "Backend resume",
      body: "Experience\n- Built and maintained the platform.",
      email: "candidate@example.com",
      full_name: "Ada Lovelace",
      headline: "Senior backend engineer",
      phone: "+1 555 0100",
      location: "Remote",
      linkedin_url: "https://www.linkedin.com/in/ada",
      github_url: "https://github.com/ada",
      portfolio_url: "https://ada.example.com"
    })
  end

  def resume_fixture(%Scope{} = scope, attrs \\ %{}) do
    {:ok, resume} =
      scope
      |> Resumes.create_resume(valid_resume_attributes(attrs))

    resume
  end
end
