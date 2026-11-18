defmodule TrackMyJobEx.AccountsFixtures do
  @moduledoc """
  Test helpers for creating accounts via the `TrackMyJobEx.Accounts` context.
  """

  import Ecto.Query

  alias TrackMyJobEx.Accounts
  alias TrackMyJobEx.Accounts.Scope

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Accounts.create_user()

    user
  end

  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  def user_scope_fixture(user) do
    Scope.for_user(user)
  end

  @doc """
  Creates an MCP token for the scope and returns `{token, plaintext}`.
  """
  def mcp_token_fixture(%Scope{} = scope, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{name: "Test MCP client"})
    {:ok, token, plaintext} = Accounts.create_mcp_token(scope, attrs)
    {token, plaintext}
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    TrackMyJobEx.Repo.update_all(
      from(t in Accounts.UserToken,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    TrackMyJobEx.Repo.update_all(
      from(ut in Accounts.UserToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end
end
