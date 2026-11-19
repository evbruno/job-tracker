defmodule TrackMyJobExWeb.MCPOAuthController do
  use TrackMyJobExWeb, :controller

  alias TrackMyJobEx.MCP.OAuth

  @token_endpoint "/oauth/token"
  @authorization_endpoint "/oauth/authorize"
  @registration_endpoint "/oauth/register"
  @revocation_endpoint "/oauth/revoke"

  def protected_resource(conn, _params) do
    json(conn, %{
      resource: OAuth.resource_url(),
      authorization_servers: [OAuth.issuer_url()],
      scopes_supported: [OAuth.scope()],
      bearer_methods_supported: ["header"],
      resource_documentation: OAuth.issuer_url()
    })
  end

  def authorization_server(conn, _params) do
    json(conn, %{
      issuer: OAuth.issuer_url(),
      authorization_endpoint: OAuth.issuer_endpoint(@authorization_endpoint),
      token_endpoint: OAuth.issuer_endpoint(@token_endpoint),
      registration_endpoint: OAuth.issuer_endpoint(@registration_endpoint),
      revocation_endpoint: OAuth.issuer_endpoint(@revocation_endpoint),
      response_types_supported: ["code"],
      grant_types_supported: ["authorization_code", "refresh_token"],
      code_challenge_methods_supported: ["S256"],
      token_endpoint_auth_methods_supported: ["none"],
      scopes_supported: [OAuth.scope()],
      client_id_metadata_document_supported: false
    })
  end

  def register(conn, params) do
    with true <- params["token_endpoint_auth_method"] in [nil, "none"],
         true <-
           params["grant_types"] in [
             nil,
             ["authorization_code"],
             ["authorization_code", "refresh_token"]
           ],
         true <- params["response_types"] in [nil, ["code"]],
         {:ok, client} <- OAuth.register_client(params) do
      conn
      |> put_status(:created)
      |> json(%{
        client_id: client.client_id,
        client_name: client.client_name,
        redirect_uris: client.redirect_uris,
        token_endpoint_auth_method: "none",
        grant_types: ["authorization_code", "refresh_token"],
        response_types: ["code"],
        client_id_issued_at: DateTime.to_unix(client.inserted_at)
      })
    else
      _ -> oauth_error(conn, :bad_request, "invalid_client_metadata")
    end
  end

  def authorize(conn, params) do
    case validate_authorization_request(params) do
      {:ok, client, redirect_uri} ->
        case conn.assigns[:current_scope] do
          %{user: user} when not is_nil(user) ->
            render_consent(conn, client, redirect_uri, params)

          _other ->
            conn
            |> put_session(:user_return_to, request_path_with_query(conn))
            |> redirect(to: ~p"/users/log-in")
        end

      {:error, _reason} ->
        oauth_error(conn, :bad_request, "invalid_request")
    end
  end

  def approve(conn, params) do
    with %{} = scope <- conn.assigns[:current_scope],
         user when not is_nil(user) <- scope.user,
         {:ok, client, redirect_uri} <- validate_authorization_request(params),
         {:ok, code} <-
           OAuth.create_authorization_code(%{
             client_id: client.client_id,
             user_id: scope.user.id,
             redirect_uri: redirect_uri,
             code_challenge: params["code_challenge"],
             resource: params["resource"]
           }) do
      query = [code: code] ++ if(params["state"], do: [state: params["state"]], else: [])
      redirect(conn, external: append_query(redirect_uri, query))
    else
      _ -> oauth_error(conn, :bad_request, "invalid_request")
    end
  end

  def deny(conn, params) do
    case validate_authorization_request(params) do
      {:ok, _client, redirect_uri} ->
        query =
          [error: "access_denied"] ++ if(params["state"], do: [state: params["state"]], else: [])

        redirect(conn, external: append_query(redirect_uri, query))

      {:error, _reason} ->
        oauth_error(conn, :bad_request, "invalid_request")
    end
  end

  def authorize_decision(conn, %{"decision" => "approve"} = params), do: approve(conn, params)
  def authorize_decision(conn, %{"decision" => "deny"} = params), do: deny(conn, params)
  def authorize_decision(conn, _params), do: oauth_error(conn, :bad_request, "invalid_request")

  def token(conn, %{"grant_type" => "authorization_code"} = params) do
    with true <- params["code_verifier"] |> valid_verifier?(),
         true <- params["resource"] == OAuth.resource_url(),
         {:ok, tokens} <-
           OAuth.exchange_code(%{
             code: params["code"],
             client_id: params["client_id"],
             redirect_uri: params["redirect_uri"],
             code_verifier: params["code_verifier"],
             resource: params["resource"]
           }) do
      token_response(conn, tokens)
    else
      _ -> oauth_error(conn, :bad_request, "invalid_grant")
    end
  end

  def token(conn, %{"grant_type" => "refresh_token"} = params) do
    with true <- params["resource"] == OAuth.resource_url(),
         {:ok, tokens} <-
           OAuth.refresh_tokens(%{
             refresh_token: params["refresh_token"],
             client_id: params["client_id"],
             resource: params["resource"]
           }) do
      token_response(conn, tokens)
    else
      _ -> oauth_error(conn, :bad_request, "invalid_grant")
    end
  end

  def token(conn, _params), do: oauth_error(conn, :bad_request, "unsupported_grant_type")

  def revoke(conn, %{"token" => token}) do
    OAuth.revoke_token(token)
    send_resp(conn, :ok, "")
  end

  def revoke(conn, _params), do: send_resp(conn, :ok, "")

  defp validate_authorization_request(params) do
    with true <- params["response_type"] == "code",
         true <- params["code_challenge_method"] == "S256",
         true <- OAuth.valid_pkce_challenge?(params["code_challenge"]),
         true <- params["resource"] == OAuth.resource_url(),
         true <- valid_state?(params["state"]),
         true <- params["scope"] in [nil, OAuth.scope()],
         %{} = client <- OAuth.get_client(params["client_id"]),
         redirect_uri when is_binary(redirect_uri) <- params["redirect_uri"],
         true <- redirect_uri in client.redirect_uris do
      {:ok, client, redirect_uri}
    else
      _ -> {:error, :invalid_request}
    end
  end

  defp render_consent(conn, client, redirect_uri, params) do
    values =
      Map.take(params, [
        "client_id",
        "redirect_uri",
        "response_type",
        "scope",
        "state",
        "code_challenge",
        "code_challenge_method",
        "resource"
      ])

    hidden_inputs =
      Enum.map_join(values, "\n", fn {key, value} ->
        ~s(<input type="hidden" name="#{escape(key)}" value="#{escape(value)}">)
      end)

    csrf = Plug.CSRFProtection.get_csrf_token()

    body = """
    <!doctype html>
    <html lang="en"><meta charset="utf-8"><title>Authorize Job Tracker</title>
    <body style="font:16px system-ui;max-width:36rem;margin:4rem auto;padding:0 1rem">
    <h1>Authorize #{escape(client.client_name)}</h1>
    <p>Allow this MCP client to access your Job Tracker applications, resumes, tags, and account details?</p>
    <p>Requested permission: <strong>#{OAuth.scope()}</strong></p>
    <p>Redirect destination: <code>#{escape(redirect_uri)}</code></p>
    <form method="post" action="/oauth/authorize">
    <input type="hidden" name="_csrf_token" value="#{escape(csrf)}">
    #{hidden_inputs}
    <button name="decision" value="approve">Approve</button>
    <button name="decision" value="deny">Deny</button>
    </form></body></html>
    """

    html(conn, body)
  end

  defp valid_verifier?(verifier) when is_binary(verifier) do
    byte_size(verifier) in 43..128 and Regex.match?(~r/^[A-Za-z0-9._~-]+$/, verifier)
  end

  defp valid_verifier?(_), do: false

  defp valid_state?(nil), do: true
  defp valid_state?(state) when is_binary(state), do: byte_size(state) <= 1_024
  defp valid_state?(_), do: false

  defp token_response(conn, tokens) do
    json(conn, %{
      access_token: tokens.access_token,
      token_type: "Bearer",
      expires_in: tokens.expires_in,
      refresh_token: tokens.refresh_token,
      scope: tokens.scope
    })
  end

  defp oauth_error(conn, status, error) do
    conn
    |> put_status(status)
    |> json(%{error: error})
  end

  defp append_query(uri, pairs) do
    separator = if String.contains?(uri, "?"), do: "&", else: "?"
    uri <> separator <> URI.encode_query(pairs)
  end

  defp request_path_with_query(conn) do
    if conn.query_string == "" do
      conn.request_path
    else
      conn.request_path <> "?" <> conn.query_string
    end
  end

  defp escape(value) when is_binary(value) do
    value
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  defp escape(value), do: escape(to_string(value))
end
