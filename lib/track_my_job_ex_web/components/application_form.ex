defmodule TrackMyJobExWeb.ApplicationForm do
  @moduledoc """
  Shared job application form used by the create and edit pages.
  """

  use TrackMyJobExWeb, :html

  attr :form, :any, required: true
  attr :submit_label, :string, default: "Save application"
  attr :cancel_path, :string, required: true

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
        maxlength="255"
        required
      />
      <.input
        field={@form[:recruiter_name]}
        type="text"
        label="Recruiter (optional)"
        maxlength="255"
      />
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
end
