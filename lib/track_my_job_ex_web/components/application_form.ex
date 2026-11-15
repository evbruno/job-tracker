defmodule TrackMyJobExWeb.ApplicationForm do
  @moduledoc """
  Shared job application form used by the create and edit pages.
  """

  use TrackMyJobExWeb, :html

  attr :form, :any, required: true
  attr :submit_label, :string, default: "Save application"
  attr :cancel_path, :string, required: true
  attr :company_suggestions, :list, default: []
  attr :recruiter_suggestions, :list, default: []
  attr :tags, :list, default: []
  attr :selected_tag_ids, :list, default: []
  attr :new_tags, :string, default: ""
  attr :tag_errors, :list, default: []

  def application_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id="application-form"
      phx-change="validate"
      phx-submit="save"
      class="space-y-4"
    >
      <.input
        field={@form[:position]}
        type="text"
        label="Position"
        maxlength="255"
        required
      />
      <.input
        field={@form[:company_name]}
        type="text"
        label="Company"
        placeholder="e.g. Acme Corp"
        maxlength="255"
        list="company-suggestions"
        required
      />
      <p class="text-xs text-base-content/60">
        Plain text. Leading and trailing spaces are trimmed.
      </p>
      <.input
        field={@form[:recruiter_name]}
        type="text"
        label="Recruiter (optional)"
        placeholder="e.g. Jane Recruiter"
        maxlength="255"
        list="recruiter-suggestions"
      />
      <p class="text-xs text-base-content/60">
        Optional. Leave blank to store no recruiter.
      </p>
      <.input
        field={@form[:job_posting_url]}
        type="url"
        label="Job posting URL (optional)"
        placeholder="https://example.com/jobs/123"
      />
      <.input
        field={@form[:description]}
        type="textarea"
        label="Job description (optional)"
        rows="6"
      />

      <div class="space-y-2">
        <h2 class="text-sm font-semibold">Tags</h2>
        <.input
          type="select"
          multiple
          name="tag_ids[]"
          id="application-tag-ids"
          label="Existing tags"
          options={Enum.map(@tags, &{&1.name, &1.id})}
          value={@selected_tag_ids}
        />
        <.input
          type="text"
          name="new_tags"
          id="application-new-tags"
          label="Create tags (comma separated)"
          placeholder="Elixir, Remote"
          value={@new_tags}
        />
        <p :for={message <- @tag_errors} class="text-sm text-error">
          {message}
        </p>
      </div>

      <datalist id="company-suggestions">
        <option :for={company <- @company_suggestions} value={company} />
      </datalist>
      <datalist id="recruiter-suggestions">
        <option :for={recruiter <- @recruiter_suggestions} value={recruiter} />
      </datalist>

      <div class="flex flex-wrap gap-2">
        <button type="submit" id="application-form-submit" class="btn btn-primary">
          {@submit_label}
        </button>
        <.link navigate={@cancel_path} id="application-form-cancel" class="btn btn-ghost">
          Cancel
        </.link>
      </div>
    </.form>
    """
  end

  @doc """
  Extracts tag errors from a changeset so they can be rendered next to the tag
  inputs.
  """
  def tag_errors(changeset) do
    for {:tags, {message, _opts}} <- changeset.errors, do: message
  end

  @doc """
  Splits the comma-separated new tag input into trimmed, non-blank names.
  """
  def parse_new_tag_names(value) when is_binary(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  def parse_new_tag_names(_value), do: []
end
