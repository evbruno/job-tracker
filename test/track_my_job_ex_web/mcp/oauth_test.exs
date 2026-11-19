defmodule TrackMyJobExWeb.MCP.OAuthTest do
  use TrackMyJobExWeb.ConnCase, async: false

  alias TrackMyJobEx.AccountsFixtures
  alias TrackMyJobEx.MCP.OAuth
  alias TrackMyJobExWeb.MCP.Router

  @resource "http://localhost:4002/mcp"
  @redirect_uri "http://localhost:9876/callback"
  @verifier String.duplicate("a", 43)

  setup do
    scope = AccountsFixtures.user_scope_fixture()

    {:ok, client} =
      OAuth.register_client(%{
        "client_name" => "ChatGPT",
        "redirect_uris" => [@redirect_uri]
      })

    %{scope: scope, client: client}
  end

  test "publishes protected resource and authorization server metadata", %{conn: conn} do
    resource = get(conn, "/.well-known/oauth-protected-resource/mcp")
    resource_metadata = json_response(resource, 200)
    assert resource_metadata["resource"] == @resource
    assert resource_metadata["authorization_servers"] == ["http://localhost:4002/"]

    authorization_server = get(conn, "/.well-known/oauth-authorization-server")
    metadata = json_response(authorization_server, 200)
    assert metadata["issuer"] == "http://localhost:4002/"
    assert metadata["authorization_endpoint"] == "http://localhost:4002/oauth/authorize"
    assert metadata["code_challenge_methods_supported"] == ["S256"]
    assert metadata["registration_endpoint"] == "http://localhost:4002/oauth/register"
  end

  test "DCR only accepts public clients with safe redirect URIs", %{conn: conn} do
    response =
      post(conn, "/oauth/register", %{
        client_name: "Test client",
        redirect_uris: [@redirect_uri],
        token_endpoint_auth_method: "none"
      })

    body = json_response(response, 201)
    assert body["client_id"]
    assert body["token_endpoint_auth_method"] == "none"

    bad_response =
      post(build_conn(), "/oauth/register", %{
        client_name: "Unsafe client",
        redirect_uris: ["http://evil.example/callback"],
        token_endpoint_auth_method: "client_secret_post"
      })

    assert json_response(bad_response, 400)["error"] == "invalid_client_metadata"
  end

  test "authorization code flow requires consent, PKCE, and resource-bound token exchange", %{
    conn: conn,
    scope: scope,
    client: client
  } do
    params = authorization_params(client)

    consent =
      conn
      |> log_in_user(scope.user)
      |> get("/oauth/authorize", params)

    assert consent.status == 200
    assert consent.resp_body =~ "Allow this MCP client"

    csrf_token =
      Regex.run(~r/name="_csrf_token" value="([^"]+)"/, consent.resp_body)
      |> Enum.at(1)

    approved =
      post(
        consent,
        "/oauth/authorize",
        Map.put(params, "decision", "approve") |> Map.put("_csrf_token", csrf_token)
      )

    assert approved.status == 302
    location = get_resp_header(approved, "location") |> hd()
    code = URI.decode_query(URI.parse(location).query)["code"]

    tokens =
      build_conn()
      |> post("/oauth/token", %{
        grant_type: "authorization_code",
        code: code,
        client_id: client.client_id,
        redirect_uri: @redirect_uri,
        code_verifier: @verifier,
        resource: @resource
      })
      |> json_response(200)

    assert tokens["token_type"] == "Bearer"
    assert tokens["expires_in"] == 600
    assert tokens["scope"] == "job-tracker"

    code_replay =
      post(build_conn(), "/oauth/token", %{
        grant_type: "authorization_code",
        code: code,
        client_id: client.client_id,
        redirect_uri: @redirect_uri,
        code_verifier: @verifier,
        resource: @resource
      })

    assert json_response(code_replay, 400)["error"] == "invalid_grant"

    session = Phantom.Test.build_session(Router)

    oauth_conn =
      Plug.Conn.put_req_header(build_conn(), "authorization", "Bearer " <> tokens["access_token"])

    assert {:ok, connected} = Router.connect(session, oauth_conn)
    assert connected.assigns.scope.user.id == scope.user.id

    assert :error =
             OAuth.authenticate_access_token(tokens["access_token"], "https://other.example/mcp")

    post(build_conn(), "/oauth/revoke", %{
      token: tokens["access_token"],
      token_type_hint: "access_token"
    })

    assert {:unauthorized, _challenge} =
             Router.connect(session, oauth_conn)

    rotated =
      build_conn()
      |> post("/oauth/token", %{
        grant_type: "refresh_token",
        refresh_token: tokens["refresh_token"],
        client_id: client.client_id,
        resource: @resource
      })
      |> json_response(200)

    assert rotated["refresh_token"] != tokens["refresh_token"]

    replay =
      post(build_conn(), "/oauth/token", %{
        grant_type: "refresh_token",
        refresh_token: tokens["refresh_token"],
        client_id: client.client_id,
        resource: @resource
      })

    assert json_response(replay, 400)["error"] == "invalid_grant"
  end

  test "authorization rejects unregistered redirect URIs and non-PKCE requests", %{
    conn: conn,
    client: client
  } do
    invalid =
      authorization_params(client) |> Map.put("redirect_uri", "https://evil.example/callback")

    response =
      conn
      |> log_in_user(TrackMyJobEx.AccountsFixtures.user_fixture())
      |> get("/oauth/authorize", invalid)

    assert json_response(response, 400)["error"] == "invalid_request"
  end

  defp authorization_params(client) do
    %{
      "client_id" => client.client_id,
      "redirect_uri" => @redirect_uri,
      "response_type" => "code",
      "scope" => "job-tracker",
      "state" => "state-value",
      "code_challenge" => OAuth.pkce_challenge(@verifier),
      "code_challenge_method" => "S256",
      "resource" => @resource
    }
  end
end
