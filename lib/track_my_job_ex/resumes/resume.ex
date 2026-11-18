defmodule TrackMyJobEx.Resumes.Resume do
  @moduledoc """
  A user-owned resume version.

  Resumes are independent records: each one has its own title and body, and
  there is no parent/version chain. The email is prefilled by the context from
  the signed-in user's account but remains editable.

  Optional text fields and URLs are trimmed; blank values are stored as `NULL`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias TrackMyJobEx.Tags.Tag

  @max_title 255
  @max_body 50_000
  @max_email 255
  @max_full_name 255
  @max_headline 255
  @max_phone 50
  @max_location 255

  @url_fields [:linkedin_url, :github_url, :portfolio_url]

  schema "resumes" do
    field :title, :string
    field :body, :string
    field :email, :string
    field :full_name, :string
    field :headline, :string
    field :phone, :string
    field :location, :string
    field :linkedin_url, :string
    field :github_url, :string
    field :portfolio_url, :string

    belongs_to :user, TrackMyJobEx.Accounts.User

    has_many :resume_tags, TrackMyJobEx.Resumes.ResumeTag, foreign_key: :resume_id

    many_to_many :tags, Tag,
      join_through: TrackMyJobEx.Resumes.ResumeTag,
      join_keys: [resume_id: :id, tag_id: :id],
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for creating or updating a resume.

  `user_id` is set programmatically by the context and is never cast from
  client input. The create form's email default is also supplied by the context.
  """
  def changeset(resume, attrs) do
    resume
    |> cast(attrs, [
      :title,
      :body,
      :email,
      :full_name,
      :headline,
      :phone,
      :location,
      :linkedin_url,
      :github_url,
      :portfolio_url
    ])
    |> trim_and_normalize()
    |> validate_required([:title, :body, :email])
    |> validate_length(:title, max: @max_title)
    |> validate_length(:body, max: @max_body)
    |> validate_length(:email, max: @max_email)
    |> validate_length(:full_name, max: @max_full_name)
    |> validate_length(:headline, max: @max_headline)
    |> validate_length(:phone, max: @max_phone)
    |> validate_length(:location, max: @max_location)
    |> validate_email()
    |> validate_urls()
  end

  defp trim_and_normalize(changeset) do
    changeset
    |> trim(:title)
    |> trim(:body)
    |> trim(:email)
    |> trim(:full_name)
    |> blank_to_nil(:full_name)
    |> trim(:headline)
    |> blank_to_nil(:headline)
    |> trim(:phone)
    |> blank_to_nil(:phone)
    |> trim(:location)
    |> blank_to_nil(:location)
    |> trim(:linkedin_url)
    |> blank_to_nil(:linkedin_url)
    |> trim(:github_url)
    |> blank_to_nil(:github_url)
    |> trim(:portfolio_url)
    |> blank_to_nil(:portfolio_url)
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

  defp validate_email(changeset) do
    changeset
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
  end

  defp validate_urls(changeset) do
    Enum.reduce(@url_fields, changeset, &validate_http_url(&2, &1))
  end

  defp validate_http_url(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      url ->
        case URI.new(url) do
          {:ok, %URI{scheme: scheme, host: host}}
          when scheme in ["http", "https"] and is_binary(host) and host != "" ->
            changeset

          _ ->
            add_error(changeset, field, "must be a valid http or https URL")
        end
    end
  end
end
