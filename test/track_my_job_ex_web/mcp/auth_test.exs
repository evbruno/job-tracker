defmodule TrackMyJobExWeb.MCP.AuthTest do
  use TrackMyJobExWeb.ConnCase, async: false

  alias TrackMyJobEx.Accounts
  alias TrackMyJobEx.AccountsFixtures
  alias TrackMyJobExWeb.MCP.Router

  setup do
    scope = AccountsFixtures.user_scope_fixture()
    {_token, plaintext} = AccountsFixtures.mcp_token_fixture(scope)
    %{scope: scope, token: plaintext}
  end

  describe "HTTP authentication" do
    test "rejects a request without an Authorization header", %{conn: conn} do
      conn = rpc(conn, "tools/list")

      assert conn.status == 401
      assert [www_authenticate] = get_resp_header(conn, "www-authenticate")
      assert www_authenticate =~ "Bearer"
      assert www_authenticate =~ "invalid_token"
      assert www_authenticate =~ ~s(realm="job-tracker-mcp")
    end

    test "rejects a malformed Authorization header", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Basic abc123")
        |> rpc("tools/list")

      assert conn.status == 401
    end

    test "rejects an unknown token", %{conn: conn} do
      conn =
        conn
        |> authorize("tmj_aaaaaaaaaaaaaaaa_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
        |> rpc("tools/list")

      assert conn.status == 401
    end

    test "rejects a revoked token", %{conn: conn, scope: scope, token: plaintext} do
      [token] = Accounts.list_mcp_tokens(scope)
      {:ok, _revoked} = Accounts.revoke_mcp_token(scope, token.id)

      conn =
        conn
        |> authorize(plaintext)
        |> rpc("tools/list")

      assert conn.status == 401
    end

    test "rejects a browser Origin that is not allowed", %{conn: conn, token: plaintext} do
      conn =
        conn
        |> put_req_header("origin", "https://evil.example")
        |> authorize(plaintext)
        |> rpc("tools/list")

      assert conn.status == 403
    end
  end

  describe "connect/2" do
    test "authenticates a valid Bearer token into a tenant scope", %{
      scope: scope,
      token: plaintext
    } do
      session = Phantom.Test.build_session(Router)
      conn = authorize(build_conn(), plaintext)

      assert {:ok, connected} = Router.connect(session, conn)
      assert %TrackMyJobEx.Accounts.Scope{} = connected.assigns.scope
      assert connected.assigns.scope.user.id == scope.user.id
    end

    test "returns an unauthorized challenge for missing or bad credentials", %{conn: conn} do
      session = Phantom.Test.build_session(Router)

      assert {:unauthorized, %{method: "Bearer", error: "invalid_token"}} =
               Router.connect(session, conn)

      conn = authorize(build_conn(), "not-a-token")

      assert {:unauthorized, %{method: "Bearer", error: "invalid_token"}} =
               Router.connect(session, conn)
    end

    test "ignores client-supplied ownership data", %{scope: scope, token: plaintext} do
      session = Phantom.Test.build_session(Router)
      other_scope = AccountsFixtures.user_scope_fixture()

      conn =
        build_conn(:post, "/mcp", %{"user_id" => other_scope.user.id})
        |> authorize(plaintext)

      assert {:ok, connected} = Router.connect(session, conn)
      assert connected.assigns.scope.user.id == scope.user.id
      refute connected.assigns.scope.user.id == other_scope.user.id
    end
  end

  describe "tool catalog" do
    test "exposes the documented tools" do
      names = Router.__phantom__(:info).tools |> Enum.map(& &1.name)

      assert Enum.sort(names) ==
               Enum.sort(~w[
                 account_get
                 applications_archive
                 applications_change_status
                 applications_create
                 applications_delete
                 applications_get
                 applications_list
                 applications_status_history
                 applications_unarchive
                 applications_update
                 resumes_create
                 resumes_delete
                 resumes_get
                 resumes_list
                 resumes_update
                 statuses_list
                 tags_list
               ])
    end
  end

  ## Helpers

  defp authorize(conn, token) do
    conn
    |> put_req_header("authorization", "Bearer " <> token)
    |> put_req_header("accept", "application/json, text/event-stream")
  end

  defp rpc(conn, method, id \\ 1) do
    payload = %{"jsonrpc" => "2.0", "id" => id, "method" => method, "params" => %{}}
    post(conn, "/mcp", payload)
  end
end
