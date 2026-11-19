defmodule TrackMyJobEx.Accounts.MCPOAuthClient do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @max_redirect_uri_bytes 2_048

  schema "mcp_oauth_clients" do
    field :client_id, :string
    field :client_name, :string
    field :redirect_uris, {:array, :string}
    field :token_endpoint_auth_method, :string, default: "none"
    timestamps(type: :utc_datetime)
  end

  def changeset(client, attrs) do
    client
    |> cast(attrs, [:client_id, :client_name, :redirect_uris, :token_endpoint_auth_method])
    |> validate_required([:client_id, :client_name, :redirect_uris])
    |> validate_length(:client_name, max: 200)
    |> validate_change(:redirect_uris, fn :redirect_uris, uris ->
      if is_list(uris) and length(uris) in 1..20 and Enum.all?(uris, &valid_redirect_uri?/1) do
        []
      else
        [redirect_uris: "must contain between 1 and 20 valid redirect URIs"]
      end
    end)
    |> unique_constraint(:client_id)
  end

  defp valid_redirect_uri?(uri) when is_binary(uri) do
    if byte_size(uri) > @max_redirect_uri_bytes do
      false
    else
      valid_uri?(URI.parse(uri))
    end
  end

  defp valid_redirect_uri?(_uri), do: false

  defp valid_uri?(uri) do
    case uri do
      %URI{scheme: "https", host: host, userinfo: nil, fragment: nil} when is_binary(host) ->
        true

      %URI{scheme: "http", host: host, userinfo: nil, fragment: nil}
      when host in ["localhost", "127.0.0.1", "::1"] ->
        true

      _other ->
        false
    end
  end
end
