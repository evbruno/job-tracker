defmodule TrackMyJobExWeb.McpTokenLiveTest do
  use TrackMyJobExWeb.ConnCase

  import Phoenix.LiveViewTest
  import TrackMyJobEx.AccountsFixtures

  alias TrackMyJobEx.Accounts
  alias TrackMyJobEx.Accounts.MCPOAuthToken
  alias TrackMyJobEx.Accounts.Scope
  alias TrackMyJobEx.MCP.OAuth
  alias TrackMyJobEx.Repo

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

    test "lists OAuth connections only for the current user", %{conn: conn} do
      user = user_fixture()
      other = user_fixture()
      scope = Scope.for_user(user)

      {connection, _access_token} = oauth_connection_fixture(user)
      {other_connection, _other_access_token} = oauth_connection_fixture(other)

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/mcp-tokens")

      assert has_element?(view, "#nav-mcp-tokens", "MCP")
      assert has_element?(view, "#oauth-connection-#{connection.family_id}")
      assert has_element?(view, "#oauth-connection-#{connection.family_id}", "Test MCP client")
      refute has_element?(view, "#oauth-connection-#{other_connection.family_id}")
      assert Enum.map(OAuth.list_connections(scope), & &1.family_id) == [connection.family_id]
    end

    test "revokes an OAuth connection and its token family with confirmation", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      {connection, access_token} = oauth_connection_fixture(user)

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/mcp-tokens")

      view
      |> element("#revoke-oauth-connection-#{connection.family_id}")
      |> render_click()

      assert has_element?(view, "#revoke-oauth-connection-modal")
      view |> element("#revoke-oauth-connection-modal-confirm") |> render_click()

      refute has_element?(view, "#oauth-connection-#{connection.family_id}")
      assert OAuth.list_connections(scope) == []
      assert :error = OAuth.authenticate_access_token(access_token, OAuth.resource_url())
    end

    test "a user cannot revoke another user's OAuth connection" do
      user = user_fixture()
      other = user_fixture()
      scope = Scope.for_user(user)
      {connection, access_token} = oauth_connection_fixture(other)

      assert {:error, :not_found} = OAuth.revoke_connection(scope, connection.family_id)

      assert {:ok, authenticated_user, _scope} =
               OAuth.authenticate_access_token(access_token, OAuth.resource_url())

      assert authenticated_user.id == other.id
    end
  end

  defp oauth_connection_fixture(user) do
    {:ok, client} =
      OAuth.register_client(%{
        "client_name" => "Test MCP client",
        "redirect_uris" => ["http://localhost:9876/callback"]
      })

    family_id = "family_#{System.unique_integer([:positive])}"
    access_token = "access_#{family_id}"
    now = DateTime.utc_now(:second)
    expires_at = DateTime.add(now, 600, :second)

    Repo.insert!(%MCPOAuthToken{
      token_hash: :crypto.hash(:sha256, access_token),
      token_type: "access",
      client_id: client.client_id,
      user_id: user.id,
      family_id: family_id,
      scope: OAuth.scope(),
      resource: OAuth.resource_url(),
      expires_at: expires_at
    })

    Repo.insert!(%MCPOAuthToken{
      token_hash: :crypto.hash(:sha256, "refresh_#{family_id}"),
      token_type: "refresh",
      client_id: client.client_id,
      user_id: user.id,
      family_id: family_id,
      scope: OAuth.scope(),
      resource: OAuth.resource_url(),
      expires_at: DateTime.add(now, 30 * 24 * 60 * 60, :second)
    })

    {%{family_id: family_id, client_name: client.client_name}, access_token}
  end
end
