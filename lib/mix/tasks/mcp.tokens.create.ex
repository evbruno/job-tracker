defmodule Mix.Tasks.Mcp.Tokens.Create do
  @shortdoc "Creates an MCP personal access token for an existing user"

  @moduledoc """
  Creates an MCP personal access token for an existing user.

      mix mcp.tokens.create EMAIL --name NAME [--expires-in DAYS]

  Resolves the user by email, derives the tenant scope, and creates one token
  through `TrackMyJobEx.Accounts.create_mcp_token/2`. The plaintext token is
  printed once and cannot be recovered; only a SHA-256 hash and the public
  prefix are stored.

  The user must already exist; provision the account first with
  `mix users.create EMAIL`. The task exits with a non-zero status when the user
  is unknown, the name is missing or invalid, the expiry is not in the future,
  or the token cannot be created.

  ## Options

    * `--name` - a label for the client that will use the token (required)
    * `--expires-in` - number of days until the token expires (optional)

  ## Examples

      mix mcp.tokens.create alice@example.com --name "Claude Desktop"
      mix mcp.tokens.create alice@example.com --name "CI agent" --expires-in 90
  """

  use Mix.Task

  alias TrackMyJobEx.Accounts
  alias TrackMyJobEx.Accounts.Scope

  @switches [name: :string, expires_in: :integer]
  @usage "Usage: mix mcp.tokens.create EMAIL --name NAME [--expires-in DAYS]"

  @impl Mix.Task
  def run(args) do
    if "--help" in args or "-h" in args do
      Mix.shell().info(@moduledoc)
    else
      create_token!(args)
    end
  end

  defp create_token!(args) do
    Mix.Task.run("app.start")

    {opts, argv, invalid} = OptionParser.parse(args, strict: @switches)

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}. #{@usage}")
    end

    email = parse_email!(argv)
    name = opts[:name] || Mix.raise("The --name option is required. #{@usage}")
    user = fetch_user!(email)

    attrs = %{"name" => name}
    attrs = put_expiry(attrs, opts[:expires_in], @usage)

    case Accounts.create_mcp_token(Scope.for_user(user), attrs) do
      {:ok, token, plaintext} ->
        Mix.shell().info("""
        Created MCP token #{token.id} (#{inspect(token.name)}) for #{user.email}
        Token (shown once): #{plaintext}

        Configure your MCP client with:
          Authorization: Bearer #{plaintext}
        """)

      {:error, changeset} ->
        Mix.raise("Could not create MCP token: #{format_errors(changeset)}")
    end
  end

  defp put_expiry(attrs, nil, _usage), do: attrs

  defp put_expiry(attrs, days, _usage) when is_integer(days) and days > 0 do
    expires_at =
      DateTime.utc_now(:second)
      |> DateTime.add(days * 24 * 60 * 60, :second)

    Map.put(attrs, "expires_at", expires_at)
  end

  defp put_expiry(_attrs, _days, usage) do
    Mix.raise("--expires-in must be a positive number of days. #{usage}")
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

  defp format_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(&interpolate_error/1)
    |> Enum.map_join(", ", fn {field, messages} ->
      "#{field} #{Enum.join(messages, ", ")}"
    end)
  end

  defp interpolate_error({message, opts}) do
    Enum.reduce(opts, message, fn {key, value}, acc ->
      placeholder = "%{#{key}}"

      if String.contains?(acc, placeholder) do
        String.replace(acc, placeholder, to_string(value))
      else
        acc
      end
    end)
  end
end
