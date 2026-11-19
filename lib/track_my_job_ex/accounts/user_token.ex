defmodule TrackMyJobEx.Accounts.UserToken do
  use Ecto.Schema
  import Ecto.Query
  alias TrackMyJobEx.Accounts.UserToken

  @rand_size 32
  @session_validity_in_days 14

  schema "users_tokens" do
    field :token, :binary
    field :context, :string
    field :authenticated_at, :utc_datetime
    belongs_to :user, TrackMyJobEx.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc """
  Builds a session token for the user.

  Session tokens are stored in the database so that individual sessions can be
  expired. Phoenix session cookies are signed but not persisted, so storing the
  token gives the application control over session lifetime.
  """
  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    dt = user.authenticated_at || DateTime.utc_now(:second)
    {token, %UserToken{token: token, context: "session", user_id: user.id, authenticated_at: dt}}
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the user found by the token, if any, along with the token's
  creation time. The token is valid if it matches the value in the database and
  it has not expired after #{@session_validity_in_days} days.
  """
  def verify_session_token_query(token) do
    query =
      from token in by_token_and_context_query(token, "session"),
        join: user in assoc(token, :user),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: {%{user | authenticated_at: token.authenticated_at}, token.inserted_at}

    {:ok, query}
  end

  defp by_token_and_context_query(token, context) do
    from UserToken, where: [token: ^token, context: ^context]
  end
end
