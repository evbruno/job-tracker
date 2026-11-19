# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :track_my_job_ex, :scopes,
  user: [
    default: true,
    module: TrackMyJobEx.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: TrackMyJobEx.AccountsFixtures,
    test_setup_helper: :log_in_user_fixture
  ]

config :track_my_job_ex,
  ecto_repos: [TrackMyJobEx.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :track_my_job_ex, TrackMyJobExWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: TrackMyJobExWeb.ErrorHTML, json: TrackMyJobExWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: TrackMyJobEx.PubSub,
  live_view: [signing_salt: "zKgce2b/"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  track_my_job_ex: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.3",
  track_my_job_ex: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# MCP Streamable HTTP clients negotiate Server-Sent Events alongside JSON.
config :mime, :types, %{
  "text/event-stream" => ["sse"]
}

# Browser Origins allowed to call the MCP endpoint. Requests without an Origin
# header (native MCP clients) are always allowed; this list only guards against
# browser-based DNS-rebinding attacks.
config :track_my_job_ex, :mcp_allowed_origins, ["http://localhost:4000"]

config :track_my_job_ex,
  mcp_oauth_issuer_url: "http://localhost:4000",
  mcp_resource_url: "http://localhost:4000/mcp"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
