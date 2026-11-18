defmodule TrackMyJobExWeb.MCP.Router do
  @moduledoc """
  Job Tracker MCP server.

  Provides full create, read, update, and delete access to the authenticated
  user's job applications and resumes, plus read-only access to tags and the
  predefined application statuses.

  Authentication uses a personal access token:

      Authorization: Bearer tmj_<prefix>_<secret>

  Create tokens with `mix mcp.tokens.create EMAIL --name NAME`. Every tool acts
  only on the token owner's data. Another user's identifiers are reported as not
  found.

  Applications start in the `interested` status; use `applications_change_status`
  with a status slug from `statuses_list` to move them. Tags are shared by
  applications and resumes; pass `tag_ids` to link existing tags or
  `new_tag_names` to create and link new ones.
  """

  use Phantom.Router,
    name: "Job Tracker",
    vsn: "0.1.0",
    instructions: @moduledoc,
    secret_key_base: {TrackMyJobExWeb.Endpoint, :config, [:secret_key_base]},
    request_state_salt: "track_my_job_ex mcp request_state v1"

  alias TrackMyJobEx.Accounts
  alias TrackMyJobEx.Accounts.Scope
  alias TrackMyJobExWeb.MCP.Tools

  @auth_realm "job-tracker-mcp"
  @unauthorized %{method: "Bearer", realm: @auth_realm, error: "invalid_token"}

  @impl Phantom.Router
  def connect(session, %Plug.Conn{} = conn) do
    with ["Bearer " <> token] <- Plug.Conn.get_req_header(conn, "authorization"),
         {:ok, user, _mcp_token} <- Accounts.get_user_by_mcp_token(token) do
      {:ok, Phantom.Session.assign(session, :scope, Scope.for_user(user))}
    else
      _other -> {:unauthorized, @unauthorized}
    end
  end

  def connect(_session, _adapter_info), do: {:unauthorized, @unauthorized}

  ## Applications

  tool :applications_list, Tools, [] do
    field :q, :string,
      description: "Case-insensitive partial match on the position or company name."

    field :status, :string, description: "Status slug to filter by, for example \"applied\"."

    field :company, :string, description: "Exact company name, matched case-insensitively."

    field :recruiter, :string, description: "Exact recruiter name, matched case-insensitively."

    field :tags, {:array, :integer}, description: "Tag ids; an application must have all of them."

    field :sort, :string,
      description: "Sort by \"created\" (default) or \"updated\".",
      in: ~w[created updated]

    field :direction, :string,
      description: "Sort direction, \"desc\" (default) or \"asc\".",
      in: ~w[desc asc]

    field :page, :integer, minimum: 1, description: "1-based page number; 25 per page."
  end

  tool :applications_get, Tools, [] do
    field :id, :integer, required: true, description: "The application id."
  end

  tool :applications_create, Tools, [] do
    field :position, :string, required: true, description: "The position title."

    field :company_name, :string, required: true, description: "The company name."

    field :recruiter_name, :string, description: "Optional recruiter name."

    field :description, :string, description: "Optional notes about the application."

    field :job_posting_url, :string,
      description: "Optional absolute http or https URL for the job posting."

    field :tag_ids, {:array, :integer},
      description: "Ids of existing tags owned by the caller to link."

    field :new_tag_names, {:array, :string},
      description: "Tag names to create when missing and link to the application."
  end

  tool :applications_update, Tools, [] do
    field :id, :integer, required: true, description: "The application id."

    field :position, :string, description: "The position title."
    field :company_name, :string, description: "The company name."
    field :recruiter_name, :string, description: "The recruiter name; blank clears it."
    field :description, :string, description: "Notes about the application."

    field :job_posting_url, :string,
      description: "Absolute http or https URL for the job posting; blank clears it."

    field :tag_ids, {:array, :integer},
      description:
        "Replaces the linked tags with exactly these tag ids. Omit to keep the current tags; send [] to remove all."

    field :new_tag_names, {:array, :string},
      description: "Tag names to create when missing and link to the application."
  end

  tool :applications_delete, Tools, destructive: true do
    field :id, :integer, required: true, description: "The application id to delete."
  end

  tool :applications_change_status, Tools, [] do
    field :id, :integer, required: true, description: "The application id."

    field :status, :string,
      required: true,
      description: "The target status slug from statuses_list, for example \"interviewing\"."

    field :notes, :string, description: "Optional notes, up to 2,000 characters."
  end

  tool :applications_status_history, Tools, [] do
    field :id, :integer, required: true, description: "The application id."
  end

  ## Resumes

  tool(:resumes_list, Tools, [])

  tool :resumes_get, Tools, [] do
    field :id, :integer, required: true, description: "The resume id."
  end

  tool :resumes_create, Tools, [] do
    field :title, :string, required: true, description: "The resume title."
    field :body, :string, required: true, description: "The resume text."

    field :email, :string,
      description: "Contact email; defaults to the account email when omitted."

    field :full_name, :string, description: "Optional full name."
    field :headline, :string, description: "Optional headline or current role."
    field :phone, :string, description: "Optional phone number."
    field :location, :string, description: "Optional location."

    field :linkedin_url, :string, description: "Optional absolute http or https LinkedIn URL."
    field :github_url, :string, description: "Optional absolute http or https GitHub URL."
    field :portfolio_url, :string, description: "Optional absolute http or https portfolio URL."

    field :tag_ids, {:array, :integer},
      description: "Ids of existing tags owned by the caller to link."

    field :new_tag_names, {:array, :string},
      description: "Tag names to create when missing and link to the resume."
  end

  tool :resumes_update, Tools, [] do
    field :id, :integer, required: true, description: "The resume id."

    field :title, :string, description: "The resume title."
    field :body, :string, description: "The resume text."
    field :email, :string, description: "Contact email."
    field :full_name, :string, description: "Full name; blank clears it."
    field :headline, :string, description: "Headline or current role; blank clears it."
    field :phone, :string, description: "Phone number; blank clears it."
    field :location, :string, description: "Location; blank clears it."
    field :linkedin_url, :string, description: "LinkedIn URL; blank clears it."
    field :github_url, :string, description: "GitHub URL; blank clears it."
    field :portfolio_url, :string, description: "Portfolio URL; blank clears it."

    field :tag_ids, {:array, :integer},
      description:
        "Replaces the linked tags with exactly these tag ids. Omit to keep the current tags; send [] to remove all."

    field :new_tag_names, {:array, :string},
      description: "Tag names to create when missing and link to the resume."
  end

  tool :resumes_delete, Tools, destructive: true do
    field :id, :integer, required: true, description: "The resume id to delete."
  end

  ## Reference data

  tool(:account_get, Tools, read_only: true)
  tool(:tags_list, Tools, read_only: true)

  tool(:statuses_list, Tools, read_only: true)
end
