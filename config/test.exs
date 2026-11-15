import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :track_my_job_ex, TrackMyJobEx.Repo,
  database: Path.expand("../track_my_job_ex_test.db", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox,
  journal_mode: :wal,
  foreign_keys: :on

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :track_my_job_ex, TrackMyJobExWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "2KPEJEY/7ttmkM+XMGwgCylc+KBSXllek2UGcwuDJW1zpZ2+DwTAnPCxepgMFidi",
  server: false

# In test we don't send emails
config :track_my_job_ex, TrackMyJobEx.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
