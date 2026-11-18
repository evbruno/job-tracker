defmodule TrackMyJobExWeb.ResumeForm do
  @moduledoc """
  Shared resume form used by the create and edit pages.
  """

  use TrackMyJobExWeb, :html

  attr :form, :any, required: true
  attr :submit_label, :string, default: "Save resume"
  attr :cancel_path, :string, required: true
  attr :tags, :list, default: []
  attr :selected_tag_ids, :list, default: []
  attr :new_tags, :string, default: ""
  attr :tag_errors, :list, default: []

  def resume_form(assigns) do
    ~H"""
    <.form for={@form} id="resume-form" phx-change="validate" phx-submit="save" class="mt-4">
      <div class="flex flex-col gap-4">
        <section class="rounded border border-rule bg-surface">
          <div class="border-b border-rule px-4 py-3">
            <h2 class="text-sm font-semibold text-ink">Version</h2>
            <p class="mt-0.5 text-xs text-ink-muted">
              Give each resume version a title so you can tell them apart.
            </p>
          </div>
          <div class="grid gap-4 px-4 py-4 sm:grid-cols-2">
            <.input
              field={@form[:title]}
              type="text"
              label="Title"
              placeholder="e.g. Backend — 2026"
              maxlength="255"
              required
            />
            <.input
              field={@form[:full_name]}
              type="text"
              label="Full name"
              placeholder="e.g. Ada Lovelace"
              maxlength="255"
            />
            <div class="sm:col-span-2">
              <.input
                field={@form[:headline]}
                type="text"
                label="Headline"
                placeholder="e.g. Senior backend engineer"
                maxlength="255"
              />
            </div>
          </div>
        </section>

        <section class="rounded border border-rule bg-surface">
          <div class="border-b border-rule px-4 py-3">
            <h2 class="text-sm font-semibold text-ink">Contact</h2>
            <p class="mt-0.5 text-xs text-ink-muted">
              The email starts as your account email and can be changed for this version.
            </p>
          </div>
          <div class="grid gap-4 px-4 py-4 sm:grid-cols-2">
            <.input
              field={@form[:email]}
              type="email"
              label="Email"
              maxlength="255"
              autocomplete="email"
              required
            />
            <.input
              field={@form[:phone]}
              type="text"
              label="Phone"
              maxlength="50"
              autocomplete="tel"
            />
            <div class="sm:col-span-2">
              <.input
                field={@form[:location]}
                type="text"
                label="Location"
                placeholder="e.g. Lisbon, Portugal or Remote"
                maxlength="255"
              />
            </div>
          </div>
        </section>

        <section class="rounded border border-rule bg-surface">
          <div class="border-b border-rule px-4 py-3">
            <h2 class="text-sm font-semibold text-ink">Links</h2>
            <p class="mt-0.5 text-xs text-ink-muted">
              Optional. Use full URLs starting with http:// or https://.
            </p>
          </div>
          <div class="grid gap-4 px-4 py-4 sm:grid-cols-2">
            <.input
              field={@form[:linkedin_url]}
              type="url"
              label="LinkedIn URL"
              placeholder="https://www.linkedin.com/in/you"
              inputmode="url"
            />
            <.input
              field={@form[:github_url]}
              type="url"
              label="GitHub URL"
              placeholder="https://github.com/you"
              inputmode="url"
            />
            <div class="sm:col-span-2">
              <.input
                field={@form[:portfolio_url]}
                type="url"
                label="Portfolio URL"
                placeholder="https://you.example.com"
                inputmode="url"
              />
            </div>
          </div>
        </section>

        <section class="rounded border border-rule bg-surface">
          <div class="border-b border-rule px-4 py-3">
            <h2 class="text-sm font-semibold text-ink">Body</h2>
            <p class="mt-0.5 text-xs text-ink-muted">
              Paste the resume text. Line breaks are preserved when displayed.
            </p>
          </div>
          <div class="px-4 py-4">
            <.input field={@form[:body]} type="textarea" label="Resume text" rows="14" required />
          </div>
        </section>

        <section class="rounded border border-rule bg-surface">
          <div class="border-b border-rule px-4 py-3">
            <h2 class="text-sm font-semibold text-ink">Tags</h2>
            <p class="mt-0.5 text-xs text-ink-muted">
              Tags are shared with applications. Select existing tags, or add new ones
              separated by commas.
            </p>
          </div>
          <div class="flex flex-col gap-4 px-4 py-4">
            <fieldset>
              <legend class="mb-1.5 text-[13px] font-medium text-ink">Existing tags</legend>
              <div id="resume-tag-ids" class="flex flex-wrap gap-1.5">
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
              id="resume-new-tags"
              label="New tags"
              placeholder="Elixir, Remote"
              value={@new_tags}
              autocomplete="off"
              aria-describedby="resume-new-tags-hint"
            />
            <p id="resume-new-tags-hint" class="text-xs text-ink-muted">
              Separate names with commas. Existing names are reused, keeping their
              original capitalization.
            </p>
            <p :for={message <- @tag_errors} class="text-[13px] text-red-700">
              {message}
            </p>
          </div>
        </section>
      </div>

      <div class="sticky bottom-0 z-10 mt-4 flex flex-wrap items-center gap-2 border-t border-rule bg-canvas/95 py-3 backdrop-blur">
        <button type="submit" id="resume-form-submit" class="btn btn-primary btn-sm">
          {@submit_label}
        </button>
        <.link navigate={@cancel_path} id="resume-form-cancel" class="btn btn-ghost btn-sm">
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
