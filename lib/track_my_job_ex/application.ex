defmodule TrackMyJobEx.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TrackMyJobExWeb.Telemetry,
      TrackMyJobEx.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:track_my_job_ex, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:track_my_job_ex, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TrackMyJobEx.PubSub},
      # Start a worker by calling: TrackMyJobEx.Worker.start_link(arg)
      # {TrackMyJobEx.Worker, arg},
      # Start to serve requests, typically the last entry
      TrackMyJobExWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TrackMyJobEx.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TrackMyJobExWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations? do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
