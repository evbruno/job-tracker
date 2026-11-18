defmodule TrackMyJobExWeb.MCP.Serializer do
  @moduledoc """
  Converts domain records into the JSON-friendly maps returned by MCP tools.

  The shapes are stable and intentionally exclude internal or cross-tenant
  fields: a tool only ever serializes records that were fetched through the
  caller's scope.
  """

  alias TrackMyJobEx.JobApplications.ApplicationStatusHistory
  alias TrackMyJobEx.JobApplications.JobApplication
  alias TrackMyJobEx.JobApplications.Status
  alias TrackMyJobEx.Resumes.Resume
  alias TrackMyJobEx.Tags.Tag

  @doc """
  Serializes an application with its status and tags.
  """
  def application(%JobApplication{} = application) do
    %{
      "id" => application.id,
      "position" => application.position,
      "company_name" => application.company_name,
      "recruiter_name" => application.recruiter_name,
      "description" => application.description,
      "job_posting_url" => application.job_posting_url,
      "budget_min" => application.budget_min,
      "budget_max" => application.budget_max,
      "status" => status(application.status),
      "tags" => tags(application.tags),
      "inserted_at" => datetime(application.inserted_at),
      "updated_at" => datetime(application.updated_at)
    }
  end

  @doc """
  Serializes a page of applications and its pagination metadata.
  """
  def application_page(page) do
    %{
      "applications" => Enum.map(page.entries, &application/1),
      "pagination" => %{
        "page" => page.page,
        "page_size" => page.page_size,
        "total_count" => page.total_count,
        "total_pages" => page.total_pages
      }
    }
  end

  @doc """
  Serializes a resume with its tags.
  """
  def resume(%Resume{} = resume) do
    %{
      "id" => resume.id,
      "title" => resume.title,
      "body" => resume.body,
      "email" => resume.email,
      "full_name" => resume.full_name,
      "headline" => resume.headline,
      "phone" => resume.phone,
      "location" => resume.location,
      "linkedin_url" => resume.linkedin_url,
      "github_url" => resume.github_url,
      "portfolio_url" => resume.portfolio_url,
      "tags" => tags(resume.tags),
      "inserted_at" => datetime(resume.inserted_at),
      "updated_at" => datetime(resume.updated_at)
    }
  end

  @doc """
  Serializes a status history entry.
  """
  def history(%ApplicationStatusHistory{} = history) do
    %{
      "id" => history.id,
      "previous_status" => status(history.previous_status),
      "new_status" => status(history.new_status),
      "notes" => history.notes,
      "changed_at" => datetime(history.changed_at)
    }
  end

  @doc """
  Serializes a tag.
  """
  def tag(%Tag{} = tag) do
    %{"id" => tag.id, "name" => tag.name}
  end

  @doc """
  Serializes a predefined application status.
  """
  def status(%Status{} = status) do
    %{"slug" => status.slug, "name" => status.name, "position" => status.position}
  end

  def status(nil), do: nil

  defp tags(nil), do: []

  defp tags(tags) when is_list(tags) do
    tags
    |> Enum.sort_by(&String.downcase(&1.name))
    |> Enum.map(&tag/1)
  end

  defp datetime(nil), do: nil

  defp datetime(%DateTime{} = datetime) do
    datetime |> DateTime.truncate(:second) |> DateTime.to_iso8601()
  end
end
