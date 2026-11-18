defmodule TrackMyJobExWeb.McpTokenLiveTest do
  use TrackMyJobExWeb.ConnCase

  import Phoenix.LiveViewTest
  import TrackMyJobEx.AccountsFixtures

  alias TrackMyJobEx.Accounts
  alias TrackMyJobEx.Accounts.Scope

  describe "index" do
    test "renders an empty state", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/mcp-tokens")

      assert has_element?(view, "#mcp-tokens-empty")
    end

    test "creates a token and shows the plaintext once", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/mcp-tokens")

      view
      |> form("#create-mcp-token-form", token: %{name: "Laptop", expires_in: ""})
      |> render_submit()

      assert has_element?(view, "#new-mcp-token")
      assert render(view) =~ "tmj_"

      view |> element("#dismiss-new-mcp-token") |> render_click()
      refute has_element?(view, "#new-mcp-token")
    end

    test "lists only the current user's tokens", %{conn: conn} do
      user = user_fixture()
      other = user_fixture()

      scope = Scope.for_user(user)
      other_scope = Scope.for_user(other)

      {:ok, token, _plaintext} = Accounts.create_mcp_token(scope, %{"name" => "Mine"})
      {:ok, _other_token, _} = Accounts.create_mcp_token(other_scope, %{"name" => "Other"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/mcp-tokens")

      assert has_element?(view, "#mcp-token-name-#{token.id}", "Mine")
      refute render(view) =~ "Other"
    end

    test "revokes a token with confirmation", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      {:ok, token, _plaintext} = Accounts.create_mcp_token(scope, %{"name" => "Laptop"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/mcp-tokens")

      view |> element("#revoke-mcp-token-#{token.id}") |> render_click()
      assert has_element?(view, "#revoke-mcp-token-modal")

      view |> element("#revoke-mcp-token-modal-confirm") |> render_click()

      refute has_element?(view, "#mcp-token-name-#{token.id}")
      assert Accounts.list_mcp_tokens(scope) == []
    end
  end
end
