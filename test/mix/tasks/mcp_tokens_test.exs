defmodule Mix.Tasks.Mcp.TokensTest do
  use TrackMyJobEx.DataCase, async: false

  import ExUnit.CaptureIO
  import TrackMyJobEx.AccountsFixtures

  alias Mix.Tasks.Mcp.Tokens.Create, as: CreateTask
  alias Mix.Tasks.Mcp.Tokens.List, as: ListTask
  alias Mix.Tasks.Mcp.Tokens.Revoke, as: RevokeTask
  alias TrackMyJobEx.Accounts
  alias TrackMyJobEx.Accounts.Scope

  describe "mix mcp.tokens.create" do
    test "creates a token for an existing user and prints it once" do
      user = user_fixture()

      output =
        capture_io(fn ->
          CreateTask.run([user.email, "--name", "Claude Desktop"])
        end)

      assert output =~ "Created MCP token"
      assert output =~ "Claude Desktop"
      assert output =~ "Token (shown once): tmj_"

      assert [_token] = Accounts.list_mcp_tokens(Scope.for_user(user))
    end

    test "supports --expires-in" do
      user = user_fixture()

      capture_io(fn ->
        CreateTask.run([user.email, "--name", "CI", "--expires-in", "30"])
      end)

      [token] = Accounts.list_mcp_tokens(Scope.for_user(user))
      assert %DateTime{} = token.expires_at
    end

    test "fails clearly when the user does not exist" do
      email = "missing-#{System.unique_integer([:positive])}@example.com"

      capture_io(fn ->
        assert_raise Mix.Error, ~r/No user found with email #{Regex.escape(email)}/, fn ->
          CreateTask.run([email, "--name", "x"])
        end
      end)
    end

    test "fails clearly when --name is missing" do
      user = user_fixture()

      capture_io(fn ->
        assert_raise Mix.Error, ~r/--name option is required/, fn ->
          CreateTask.run([user.email])
        end
      end)
    end

    test "fails clearly on unknown options" do
      user = user_fixture()

      capture_io(fn ->
        assert_raise Mix.Error, ~r/Invalid options/, fn ->
          CreateTask.run([user.email, "--name", "x", "--bogus"])
        end
      end)
    end
  end

  describe "mix mcp.tokens.list" do
    test "prints the user's tokens" do
      user = user_fixture()

      capture_io(fn ->
        CreateTask.run([user.email, "--name", "Laptop"])
      end)

      output =
        capture_io(fn ->
          ListTask.run([user.email])
        end)

      assert output =~ user.email
      assert output =~ "Laptop"
    end

    test "prints a helpful message when there are no tokens" do
      user = user_fixture()

      output =
        capture_io(fn ->
          ListTask.run([user.email])
        end)

      assert output =~ "No MCP tokens"
    end

    test "fails clearly when the user does not exist" do
      email = "missing-#{System.unique_integer([:positive])}@example.com"

      capture_io(fn ->
        assert_raise Mix.Error, ~r/No user found with email #{Regex.escape(email)}/, fn ->
          ListTask.run([email])
        end
      end)
    end
  end

  describe "mix mcp.tokens.revoke" do
    test "revokes an existing token" do
      user = user_fixture()

      capture_io(fn ->
        CreateTask.run([user.email, "--name", "Laptop"])
      end)

      [token] = Accounts.list_mcp_tokens(Scope.for_user(user))

      output =
        capture_io(fn ->
          RevokeTask.run([user.email, to_string(token.id)])
        end)

      assert output =~ "Revoked MCP token #{token.id}"
      assert Accounts.list_mcp_tokens(Scope.for_user(user)) == []
    end

    test "fails clearly for an unknown token id" do
      user = user_fixture()

      capture_io(fn ->
        assert_raise Mix.Error, ~r/No MCP token 999999 found/, fn ->
          RevokeTask.run([user.email, "999999"])
        end
      end)
    end

    test "fails clearly on invalid arguments" do
      user = user_fixture()

      capture_io(fn ->
        assert_raise Mix.Error, ~r/Usage: mix mcp.tokens.revoke EMAIL TOKEN_ID/, fn ->
          RevokeTask.run([user.email])
        end
      end)
    end
  end
end
