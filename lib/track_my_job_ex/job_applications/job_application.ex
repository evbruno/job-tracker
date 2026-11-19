defmodule TrackMyJobEx.JobApplications.JobApplication do
  @moduledoc """
  A job application belonging to a user.

  `company_name` and `recruiter_name` are plain text columns; there are no
  separate company or recruiter records. Both are trimmed and a blank
  recruiter is stored as `NULL`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias TrackMyJobEx.JobApplications.Status
  alias TrackMyJobEx.Tags.Tag

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
    field :budget_min, :integer
    field :budget_max, :integer
    field :start_date, :date
    field :archived_at, :utc_datetime

    belongs_to :status, Status
    belongs_to :user, TrackMyJobEx.Accounts.User

    has_many :status_histories, TrackMyJobEx.JobApplications.ApplicationStatusHistory,
      foreign_key: :application_id

    has_many :application_tags, TrackMyJobEx.JobApplications.ApplicationTag,
      foreign_key: :application_id

    many_to_many :tags, Tag,
      join_through: TrackMyJobEx.JobApplications.ApplicationTag,
      join_keys: [application_id: :id, tag_id: :id],
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for creating or updating an application.

  `user_id` and `status_id` are set programmatically by the context and are not
  accepted from client input.
  """
  def changeset(job_application, attrs) do
    attrs = normalize_attributes(attrs)

    job_application
    |> cast(attrs, [
      :position,
      :description,
      :job_posting_url,
      :company_name,
      :recruiter_name,
      :budget_min,
      :budget_max,
      :start_date
    ])
    |> trim_and_normalize()
    |> validate_required([:position, :company_name])
    |> validate_length(:position, max: @max_position)
    |> validate_length(:company_name, max: @max_company_name)
    |> validate_length(:recruiter_name, max: @max_recruiter_name)
    |> validate_length(:description, max: @max_description)
    |> validate_job_posting_url()
    |> validate_budget()
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

  defp normalize_attributes(attrs) when is_map(attrs) do
    attrs
    |> normalize_start_date()
    |> normalize_budget()
  end

  defp normalize_attributes(attrs), do: attrs

  defp normalize_start_date(attrs) do
    key = if Map.has_key?(attrs, :start_date), do: :start_date, else: "start_date"

    case Map.get(attrs, key) do
      "" -> Map.put(attrs, key, nil)
      _ -> attrs
    end
  end

  defp normalize_budget(attrs) when is_map(attrs) do
    key_style = if Map.has_key?(attrs, :budget_min), do: :atom, else: :string

    Enum.reduce([:budget_min, :budget_max], attrs, fn field, acc ->
      normalize_budget_field(acc, field, key_style)
    end)
  end

  defp normalize_budget_field(attrs, field, key_style) do
    key = if key_style == :atom, do: field, else: Atom.to_string(field)
    value = Map.get(attrs, key)

    new_value =
      cond do
        is_nil(value) ->
          nil

        value == "" ->
          nil

        is_binary(value) ->
          case Integer.parse(String.trim(value)) do
            {n, ""} -> n
            _ -> value
          end

        true ->
          value
      end

    if new_value == value do
      attrs
    else
      Map.put(attrs, key, new_value)
    end
  end

  defp validate_budget(changeset) do
    changeset
    |> validate_number(:budget_min, greater_than_or_equal_to: 0)
    |> validate_number(:budget_max, greater_than_or_equal_to: 0)
    |> validate_budget_range()
  end

  defp validate_budget_range(changeset) do
    min = get_field(changeset, :budget_min)
    max = get_field(changeset, :budget_max)

    if is_integer(min) and is_integer(max) and min > max do
      add_error(changeset, :budget_max, "must be greater than or equal to the minimum")
    else
      changeset
    end
  end
end
