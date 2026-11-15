defmodule TrackMyJobEx.JobApplications.JobApplication do
  @moduledoc """
  A job application belonging to a user.

  `company_name` and `recruiter_name` are plain text columns; there are no
  separate company or recruiter records. Both are trimmed and a blank
  recruiter is stored as `NULL`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @max_position 255
  @max_company_name 255
  @max_recruiter_name 255
  @max_description 20_000

  schema "job_applications" do
    field :position, :string
    field :description, :string
    field :job_posting_url, :string
    field :company_name, :string
    field :recruiter_name, :string

    field :status_id, :id

    belongs_to :user, TrackMyJobEx.Accounts.User

    has_many :status_histories, TrackMyJobEx.JobApplications.ApplicationStatusHistory,
      foreign_key: :application_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for creating or updating an application.

  `user_id` and `status_id` are set programmatically by the context and are not
  accepted from client input.
  """
  def changeset(job_application, attrs) do
    job_application
    |> cast(attrs, [
      :position,
      :description,
      :job_posting_url,
      :company_name,
      :recruiter_name
    ])
    |> trim_and_normalize()
    |> validate_required([:position, :company_name])
    |> validate_length(:position, max: @max_position)
    |> validate_length(:company_name, max: @max_company_name)
    |> validate_length(:recruiter_name, max: @max_recruiter_name)
    |> validate_length(:description, max: @max_description)
    |> validate_job_posting_url()
  end

  defp trim_and_normalize(changeset) do
    changeset
    |> trim(:position)
    |> trim(:company_name)
    |> trim(:recruiter_name)
    |> blank_to_nil(:recruiter_name)
    |> trim(:job_posting_url)
    |> blank_to_nil(:job_posting_url)
  end

  defp trim(changeset, field) do
    case get_change(changeset, field) do
      value when is_binary(value) -> put_change(changeset, field, String.trim(value))
      _ -> changeset
    end
  end

  defp blank_to_nil(changeset, field) do
    if get_change(changeset, field) == "" do
      put_change(changeset, field, nil)
    else
      changeset
    end
  end

  defp validate_job_posting_url(changeset) do
    case get_change(changeset, :job_posting_url) do
      nil ->
        changeset

      url ->
        case URI.new(url) do
          {:ok, %URI{scheme: scheme, host: host}}
          when scheme in ["http", "https"] and is_binary(host) and host != "" ->
            changeset

          _ ->
            add_error(changeset, :job_posting_url, "must be a valid http or https URL")
        end
    end
  end
end
