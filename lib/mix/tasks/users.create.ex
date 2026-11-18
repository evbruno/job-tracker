defmodule Mix.Tasks.Users.Create do
  @shortdoc "Provisions a user with an email and password"

  @moduledoc """
  Provisions a user account.

      mix users.create EMAIL [--password PASSWORD]

  Public registration is disabled, so this task is the only supported way to
  create users. If `--password` is omitted, the task prompts for the password
  twice. The password is validated by the same changeset used by the
  application (minimum 12 characters), and email uniqueness is case-insensitive.

  The task exits with a non-zero status when the arguments are invalid, the
  email is already taken, or the password does not satisfy the changeset rules.
  """

  use Mix.Task

  alias TrackMyJobEx.Accounts

  @switches [password: :string, admin: :boolean]

  @impl Mix.Task
  def run(args) do
    if "--help" in args or "-h" in args do
      Mix.shell().info(@moduledoc)
    else
      create_user!(args)
    end
  end

  defp create_user!(args) do
    Mix.Task.run("app.start")

    {opts, argv, invalid} = OptionParser.parse(args, strict: @switches)

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}. Usage: mix users.create EMAIL")
    end

    email = parse_email!(argv)
    password = opts[:password] || prompt_password!()

    case Accounts.create_user(%{email: email, password: password, is_admin: opts[:admin] == true}) do
      {:ok, user} ->
        Mix.shell().info("Created user #{user.email}")

      {:error, changeset} ->
        Mix.raise("Could not create user: #{format_errors(changeset)}")
    end
  end

  defp parse_email!([email]) when is_binary(email) and email != "", do: email

  defp parse_email!(_argv) do
    Mix.raise("Usage: mix users.create EMAIL [--password PASSWORD]")
  end

  defp prompt_password! do
    password = read_password!("Password: ")
    confirmation = read_password!("Confirm password: ")

    if password != confirmation do
      Mix.raise("Passwords do not match")
    end

    password
  end

  defp read_password!(prompt) do
    case :io.get_password(to_charlist(prompt)) do
      :eof -> Mix.raise("No password provided")
      password -> to_string(password)
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
      interpolate(acc, key, value)
    end)
  end

  defp interpolate(message, key, value) do
    placeholder = "%{#{key}}"

    if String.contains?(message, placeholder) do
      String.replace(message, placeholder, to_string(value))
    else
      message
    end
  end
end
