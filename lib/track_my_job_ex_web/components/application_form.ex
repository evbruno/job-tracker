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
      class="mt-4"
    >
      <div class="flex flex-col gap-4">
        <section class="rounded border border-rule bg-surface">
          <div class="border-b border-rule px-4 py-3">
            <h2 class="text-sm font-semibold text-ink">Role</h2>
            <p class="mt-0.5 text-xs text-ink-muted">
              Position and company are required. Both are trimmed on save.
            </p>
          </div>
          <div class="grid gap-4 px-4 py-4 sm:grid-cols-2">
            <.input
              field={@form[:position]}
              type="text"
              label="Position"
              placeholder="e.g. Backend Engineer"
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
              autocomplete="off"
              required
            />
          </div>
        </section>

        <section class="rounded border border-rule bg-surface">
          <div class="border-b border-rule px-4 py-3">
            <h2 class="text-sm font-semibold text-ink">Recruiter and posting</h2>
            <p class="mt-0.5 text-xs text-ink-muted">
              Optional. Leave the recruiter blank to store none, or leave the URL
              blank if there is no posting.
            </p>
          </div>
          <div class="grid gap-4 px-4 py-4 sm:grid-cols-2">
            <.input
              field={@form[:recruiter_name]}
              type="text"
              label="Recruiter"
              placeholder="e.g. Jane Recruiter"
              maxlength="255"
              list="recruiter-suggestions"
              autocomplete="off"
            />
            <.input
              field={@form[:job_posting_url]}
              type="url"
              label="Job posting URL"
              placeholder="https://example.com/jobs/123"
              inputmode="url"
            />
          </div>
        </section>

        <section class="rounded border border-rule bg-surface">
          <div class="border-b border-rule px-4 py-3">
            <h2 class="text-sm font-semibold text-ink">Description</h2>
            <p class="mt-0.5 text-xs text-ink-muted">
              Optional notes about the role, the team, or the process.
            </p>
          </div>
          <div class="px-4 py-4">
            <.input
              field={@form[:description]}
              type="textarea"
              label="Job description"
              rows="6"
            />
          </div>
        </section>

        <section class="rounded border border-rule bg-surface">
          <div class="border-b border-rule px-4 py-3">
            <h2 class="text-sm font-semibold text-ink">Tags</h2>
            <p class="mt-0.5 text-xs text-ink-muted">
              Select existing tags, or add new ones separated by commas.
            </p>
          </div>
          <div class="flex flex-col gap-4 px-4 py-4">
            <fieldset>
              <legend class="mb-1.5 text-[13px] font-medium text-ink">Existing tags</legend>
              <div id="application-tag-ids" class="flex flex-wrap gap-1.5">
                <label :for={tag <- @tags} class="relative inline-flex">
                  <input
                    type="checkbox"
                    name="tag_ids[]"
                    value={tag.id}
                    checked={selected?(@selected_tag_ids, tag.id)}
                    class="peer sr-only"
                  />
                  <span class={[
                    "inline-flex cursor-pointer items-center rounded border border-rule bg-surface px-2 py-1 text-xs text-ink-muted",
                    "peer-checked:border-ink peer-checked:bg-ink peer-checked:text-white",
                    "peer-focus-visible:outline peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2 peer-focus-visible:outline-cobalt"
                  ]}>
                    {tag.name}
                  </span>
                </label>
                <p :if={@tags == []} class="text-xs text-ink-muted">
                  No tags yet. Add one below.
                </p>
              </div>
            </fieldset>

            <.input
              type="text"
              name="new_tags"
              id="application-new-tags"
              label="New tags"
              placeholder="Elixir, Remote"
              value={@new_tags}
              autocomplete="off"
              aria-describedby="application-new-tags-hint"
            />
            <p id="application-new-tags-hint" class="text-xs text-ink-muted">
              Separate names with commas. Existing names are reused, keeping
              their original capitalization.
            </p>
            <p :for={message <- @tag_errors} class="text-[13px] text-red-700">
              {message}
            </p>
          </div>
        </section>
      </div>

      <datalist id="company-suggestions">
        <option :for={company <- @company_suggestions} value={company} />
      </datalist>
      <datalist id="recruiter-suggestions">
        <option :for={recruiter <- @recruiter_suggestions} value={recruiter} />
      </datalist>

      <div class="sticky bottom-0 z-10 mt-4 flex flex-wrap items-center gap-2 border-t border-rule bg-canvas/95 py-3 backdrop-blur">
        <button type="submit" id="application-form-submit" class="btn btn-primary btn-sm">
          {@submit_label}
        </button>
        <.link navigate={@cancel_path} id="application-form-cancel" class="btn btn-ghost btn-sm">
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
