defmodule TrackMyJobEx.Accounts do
  @moduledoc """
  The Accounts context.

  Users are provisioned by an administrator through the `mix users.create`
  task. There is no public registration. Authentication lookups are intentionally
  global because the user is the tenant being identified; user-owned domain
  data must be queried through scoped context functions instead.
  """

  import Ecto.Query, warn: false
  alias TrackMyJobEx.Repo

  alias TrackMyJobEx.Accounts.{User, UserToken}

  ## Database getters

  @doc """
  Gets a user by email.

  Email comparisons are case-insensitive because the users table uses
  `COLLATE NOCASE` on the email column.
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  Returns `nil` when the email is unknown or the password is invalid.
  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  ## User provisioning

  @doc """
  Provisions a user with an email and password.

  This is the only way to create users. Public registration is disabled.
  """
  def create_user(attrs) do
    %User{}
    |> User.creation_changeset(attrs)
    |> Repo.insert()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end
end
