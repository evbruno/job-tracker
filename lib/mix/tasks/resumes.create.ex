defmodule Mix.Tasks.Resumes.Create do
  @shortdoc "Creates a simple resume for an existing user"

  @moduledoc """
  Creates a simple resume version for an existing user.

      mix resumes.create EMAIL [--title TITLE]

  Resolves the user by email and creates one resume owned by that user. The
  resume email is prefilled from the user's account, and the body starts as a
  short editable outline. The resume is created through
  `TrackMyJobEx.Resumes.create_resume/2`, so it follows the same validation and
  ownership rules as the web interface.

  The user must already exist; provision the account first with
  `mix users.create EMAIL`. The task exits with a non-zero status when the user
  is unknown, the title is invalid, or the resume cannot be created.

  ## Options

    * `--title` - the resume title (defaults to `Simple resume`)

  ## Examples

      mix resumes.create alice@example.com
      mix resumes.create alice@example.com --title "Backend Engineer"
  """

  use Mix.Task

  alias TrackMyJobEx.Accounts
  alias TrackMyJobEx.Accounts.Scope
  alias TrackMyJobEx.Resumes

  @switches [title: :string]
  @default_title "Simple resume"

  @body """
  Summary

  Write a short summary of your experience, strengths, and what you are looking
  for next.

  Experience

  Add your most relevant roles, responsibilities, and achievements.

  Skills

  List the technologies, tools, and practices you know best.
  """

  @impl Mix.Task
  def run(args) do
    if "--help" in args or "-h" in args do
      Mix.shell().info(@moduledoc)
    else
      create_resume!(args)
    end
  end

  defp create_resume!(args) do
    Mix.Task.run("app.start")

    {opts, argv, invalid} = OptionParser.parse(args, strict: @switches)

    if invalid != [] do
      Mix.raise(
        "Invalid options: #{inspect(invalid)}. Usage: mix resumes.create EMAIL [--title TITLE]"
      )
    end

    email = parse_email!(argv)
    title = opts[:title] || @default_title
    user = fetch_user!(email)

    attrs = %{"title" => title, "body" => @body}

    case Resumes.create_resume(Scope.for_user(user), attrs) do
      {:ok, resume} ->
        Mix.shell().info("Created resume #{inspect(resume.title)} for #{user.email}")

      {:error, changeset} ->
        Mix.raise("Could not create resume: #{format_errors(changeset)}")
    end
  end

  defp parse_email!([email]) when is_binary(email) and email != "", do: email

  defp parse_email!(_argv) do
    Mix.raise("Usage: mix resumes.create EMAIL [--title TITLE]")
  end

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
