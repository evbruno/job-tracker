defmodule TrackMyJobEx.AccountsMCPTokensTest do
  use TrackMyJobEx.DataCase, async: false

  import Ecto.Query

  alias TrackMyJobEx.Accounts
  alias TrackMyJobEx.Accounts.MCPToken
  alias TrackMyJobEx.AccountsFixtures
  alias TrackMyJobEx.Repo

  setup do
    scope = AccountsFixtures.user_scope_fixture()
    %{scope: scope, other_scope: AccountsFixtures.user_scope_fixture()}
  end

  describe "create_mcp_token/2" do
    test "returns a plaintext token once and stores only the prefix and hash", %{scope: scope} do
      assert {:ok, token, plaintext} = Accounts.create_mcp_token(scope, %{"name" => "  Laptop  "})

      assert String.starts_with?(plaintext, "tmj_")
      assert token.name == "Laptop"
      assert token.user_id == scope.user.id
      assert is_nil(token.last_used_at)
      assert is_nil(token.expires_at)

      assert {:ok, prefix} = MCPToken.prefix_from_token(plaintext)
      assert token.token_prefix == prefix

      stored = Repo.get!(MCPToken, token.id)
      refute stored.token_hash == plaintext
      assert byte_size(stored.token_hash) == 32
    end

    test "never accepts a client-provided owner", %{scope: scope, other_scope: other} do
      assert {:ok, token, _plaintext} =
               Accounts.create_mcp_token(scope, %{
                 "name" => "Mine",
                 "user_id" => other.user.id
               })

      assert token.user_id == scope.user.id
    end

    test "requires a name", %{scope: scope} do
      assert {:error, changeset} = Accounts.create_mcp_token(scope, %{"name" => "  "})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects an expiry in the past", %{scope: scope} do
      expires_at = DateTime.add(DateTime.utc_now(:second), -60, :second)

      assert {:error, changeset} =
               Accounts.create_mcp_token(scope, %{"name" => "Old", "expires_at" => expires_at})

      assert %{expires_at: ["must be in the future"]} = errors_on(changeset)
    end
  end

  describe "list_mcp_tokens/1 and get_mcp_token/2" do
    test "lists only the scope's tokens", %{scope: scope, other_scope: other} do
      {token, _plaintext} = AccountsFixtures.mcp_token_fixture(scope)
      AccountsFixtures.mcp_token_fixture(other)

      assert [listed] = Accounts.list_mcp_tokens(scope)
      assert listed.id == token.id
    end

    test "another user's token id behaves as not found", %{scope: scope, other_scope: other} do
      {token, _plaintext} = AccountsFixtures.mcp_token_fixture(other)

      assert is_nil(Accounts.get_mcp_token(scope, token.id))
    end
  end

  describe "revoke_mcp_token/2" do
    test "hard-deletes the caller's token and stops authenticating", %{scope: scope} do
      {token, plaintext} = AccountsFixtures.mcp_token_fixture(scope)
      assert {:ok, user, _token} = Accounts.get_user_by_mcp_token(plaintext)
      assert user.id == scope.user.id

      assert {:ok, revoked} = Accounts.revoke_mcp_token(scope, token.id)
      assert revoked.id == token.id
      assert is_nil(Repo.get(MCPToken, token.id))
      assert :error = Accounts.get_user_by_mcp_token(plaintext)
    end

    test "another user's token is not revoked", %{scope: scope, other_scope: other} do
      {token, plaintext} = AccountsFixtures.mcp_token_fixture(other)

      assert {:error, :not_found} = Accounts.revoke_mcp_token(scope, token.id)
      assert Repo.get(MCPToken, token.id)
      assert {:ok, _user, _token} = Accounts.get_user_by_mcp_token(plaintext)
    end
  end

  describe "get_user_by_mcp_token/1" do
    test "authenticates a valid token and refreshes last_used_at", %{scope: scope} do
      {token, plaintext} = AccountsFixtures.mcp_token_fixture(scope)

      assert {:ok, user, used} = Accounts.get_user_by_mcp_token(plaintext)
      assert user.id == scope.user.id
      assert used.id == token.id

      refreshed = Repo.get!(MCPToken, token.id)
      assert %DateTime{} = refreshed.last_used_at
    end

    test "does not refresh last_used_at within the throttle window", %{scope: scope} do
      {token, plaintext} = AccountsFixtures.mcp_token_fixture(scope)

      recent = DateTime.add(DateTime.utc_now(:second), -30, :second)

      from(t in MCPToken, where: t.id == ^token.id)
      |> Repo.update_all(set: [last_used_at: recent])

      assert {:ok, _user, _token} = Accounts.get_user_by_mcp_token(plaintext)

      assert Repo.get!(MCPToken, token.id).last_used_at == recent
    end

    test "refreshes a stale last_used_at", %{scope: scope} do
      {token, plaintext} = AccountsFixtures.mcp_token_fixture(scope)

      stale = DateTime.add(DateTime.utc_now(:second), -10 * 60, :second)

      from(t in MCPToken, where: t.id == ^token.id)
      |> Repo.update_all(set: [last_used_at: stale])

      assert {:ok, _user, _token} = Accounts.get_user_by_mcp_token(plaintext)

      assert DateTime.compare(Repo.get!(MCPToken, token.id).last_used_at, stale) == :gt
    end

    test "rejects malformed, unknown, and tampered tokens", %{scope: scope} do
      {token, plaintext} = AccountsFixtures.mcp_token_fixture(scope)

      assert :error = Accounts.get_user_by_mcp_token("not-a-token")
      assert :error = Accounts.get_user_by_mcp_token("tmj_nope_nope")
      assert :error = Accounts.get_user_by_mcp_token("tmj_" <> token.token_prefix <> "_wrong")
      assert {:ok, _user, _token} = Accounts.get_user_by_mcp_token(plaintext)
    end

    test "rejects an expired token", %{scope: scope} do
      {token, plaintext} = AccountsFixtures.mcp_token_fixture(scope)

      past = DateTime.add(DateTime.utc_now(:second), -1, :second)

      from(t in MCPToken, where: t.id == ^token.id)
      |> Repo.update_all(set: [expires_at: past])

      assert :error = Accounts.get_user_by_mcp_token(plaintext)
    end

    test "rejects non-binary input" do
      assert :error = Accounts.get_user_by_mcp_token(nil)
    end
  end
end
