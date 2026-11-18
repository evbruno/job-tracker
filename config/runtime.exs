import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/track_my_job_ex start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :track_my_job_ex, TrackMyJobExWeb.Endpoint, server: true
end

config :track_my_job_ex, TrackMyJobExWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# Browser Origins allowed to call the MCP endpoint (comma-separated). Native
# MCP clients send no Origin header and are unaffected.
if origins = System.get_env("MCP_ALLOWED_ORIGINS") do
  config :track_my_job_ex,
         :mcp_allowed_origins,
         origins |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
end

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :track_my_job_ex, TrackMyJobExWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        # Gettext translations
        ~r"priv/gettext/.*\.po$"E,
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/track_my_job_ex_web/router\.ex$"E,
        ~r"lib/track_my_job_ex_web/(controllers|live|components)/.*\.(ex|heex)$"E
      ]
    ]
end

if config_env() == :prod do
  # The SQLite file must live on a persistent volume. The parent directory is
  # created on boot so a fresh volume can be mounted without a manual mkdir.
  # SQLite creates the database file itself, but not its parent directory.
  database_path =
    System.get_env("DATABASE_PATH") ||
      Path.join([System.get_env("DATA_DIR") || "/data", "track_my_job_ex", "track_my_job_ex.db"])

  unless database_path == ":memory:" do
    File.mkdir_p!(Path.dirname(database_path))
  end

  # SQLite has a single-writer model. WAL allows concurrent readers, so a small
  # pool (1-5) is appropriate; the writer is serialized by SQLite's busy
  # handler. The busy timeout and queue settings make short write contention
  # wait and retry instead of failing immediately.
  config :track_my_job_ex, TrackMyJobEx.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5"),
    journal_mode: :wal,
    foreign_keys: :on,
    busy_timeout: String.to_integer(System.get_env("SQLITE_BUSY_TIMEOUT") || "5000"),
    queue_target: 50,
    queue_interval: 1_000

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :track_my_job_ex, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :track_my_job_ex, TrackMyJobExWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://bandit.hexdocs.pm/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :track_my_job_ex, TrackMyJobExWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://plug.hexdocs.pm/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :track_my_job_ex, TrackMyJobExWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
