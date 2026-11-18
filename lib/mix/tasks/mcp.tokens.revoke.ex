defmodule Mix.Tasks.Mcp.Tokens.Revoke do
  @shortdoc "Revokes an MCP personal access token"

  @moduledoc """
  Revokes an MCP personal access token owned by an existing user.

      mix mcp.tokens.revoke EMAIL TOKEN_ID

  Resolves the user by email and hard-deletes the token through
  `TrackMyJobEx.Accounts.revoke_mcp_token/2`. The token stops authenticating
  immediately. Another user's token id behaves as not found.

  ## Example

      mix mcp.tokens.revoke alice@example.com 12
  """

  use Mix.Task

  alias TrackMyJobEx.Accounts
  alias TrackMyJobEx.Accounts.Scope

  @usage "Usage: mix mcp.tokens.revoke EMAIL TOKEN_ID"

  @impl Mix.Task
  def run(args) do
    if "--help" in args or "-h" in args do
      Mix.shell().info(@moduledoc)
    else
      revoke_token!(args)
    end
  end

  defp revoke_token!(args) do
    Mix.Task.run("app.start")

    {email, token_id} = parse_args!(args)
    user = fetch_user!(email)

    case Accounts.revoke_mcp_token(Scope.for_user(user), token_id) do
      {:ok, token} ->
        Mix.shell().info(
          "Revoked MCP token #{token.id} (#{inspect(token.name)}) for #{user.email}"
        )

      {:error, :not_found} ->
        Mix.raise("No MCP token #{token_id} found for #{user.email}.")
    end
  end

  defp parse_args!([email, token_id]) when is_binary(email) and email != "" do
    case Integer.parse(token_id) do
      {id, ""} when id > 0 -> {email, id}
      _other -> Mix.raise(@usage)
    end
  end

  defp parse_args!(_argv), do: Mix.raise(@usage)

  defp fetch_user!(email) do
    case Accounts.get_user_by_email(email) do
      nil ->
        Mix.raise(
          "No user found with email #{email}. " <>
            "Create the user first with: mix users.create #{email}"
        )

      user ->
        user
    end
  end
end
