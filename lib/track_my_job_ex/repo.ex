defmodule TrackMyJobEx.Repo do
  use Ecto.Repo,
    otp_app: :track_my_job_ex,
    adapter: Ecto.Adapters.SQLite3
end
