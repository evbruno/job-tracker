defmodule Mix.Tasks.Mcp.Tokens.List do
  @shortdoc "Lists MCP personal access tokens for an existing user"

  @moduledoc """
  Lists the MCP personal access tokens owned by an existing user.

      mix mcp.tokens.list EMAIL

  Resolves the user by email and lists the tokens through
  `TrackMyJobEx.Accounts.list_mcp_tokens/1`, so only that user's tokens are
  shown. The plaintext token is never stored and cannot be listed.

  ## Example

      mix mcp.tokens.list alice@example.com
  """

  use Mix.Task

  alias TrackMyJobEx.Accounts
  alias TrackMyJobEx.Accounts.Scope

  @usage "Usage: mix mcp.tokens.list EMAIL"

  @impl Mix.Task
  def run(args) do
    if "--help" in args or "-h" in args do
      Mix.shell().info(@moduledoc)
    else
      list_tokens!(args)
    end
  end

  defp list_tokens!(args) do
    Mix.Task.run("app.start")

    email = parse_email!(args)
    user = fetch_user!(email)
    tokens = Accounts.list_mcp_tokens(Scope.for_user(user))

    if tokens == [] do
      Mix.shell().info("No MCP tokens for #{user.email}.")
    else
      Mix.shell().info("MCP tokens for #{user.email}:")

      Enum.each(tokens, fn token ->
        Mix.shell().info(
          "  #{token.id}\t#{token.name}\t#{token.token_prefix}…\t" <>
            "created #{format_datetime(token.inserted_at)}\t" <>
            "last used #{format_datetime(token.last_used_at)}\t" <>
            "expires #{format_datetime(token.expires_at) || "never"}"
        )
      end)
    end
  end

  defp parse_email!([email]) when is_binary(email) and email != "", do: email
  defp parse_email!(_argv), do: Mix.raise(@usage)

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

  defp format_datetime(nil), do: nil

  defp format_datetime(%DateTime{} = datetime) do
    datetime |> DateTime.truncate(:second) |> DateTime.to_iso8601()
  end
end
