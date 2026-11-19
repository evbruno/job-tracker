defmodule Mix.Tasks.Demo.Seed do
  @shortdoc "Seeds the demo user with five sample applications"

  @moduledoc """
  Seeds a demo account and sample job applications.

      mix demo.seed [--password PASSWORD]

  Creates the user `demo@example.com` (or reuses it when it already exists) and
  five sample applications owned by that user. Each application is created
  through `TrackMyJobEx.JobApplications.create_application_with_tags/4`, so it
  receives the default `Interested` status, its initial status history record,
  and its tags exactly as an application created through the UI would.

  When `--password` is omitted and the demo user does not exist yet, the task
  prompts for the password twice. Passwords follow the same rules as
  `mix users.create` (minimum 12 characters).

  The task is intended for local development and demos only. It exits with a
  non-zero status when the user or any application cannot be created.
  """

  use Mix.Task

  alias TrackMyJobEx.Accounts
  alias TrackMyJobEx.Accounts.Scope
  alias TrackMyJobEx.JobApplications

  @demo_email "demo@example.com"

  @demo_applications [
    %{
      attributes: %{
        "position" => "Senior Elixir Engineer",
        "company_name" => "Northwind Labs",
        "recruiter_name" => "Dana Whitfield",
        "job_posting_url" => "https://northwind.example.com/careers/senior-elixir-engineer",
        "description" =>
          "Build and operate Elixir services for our logistics platform. " <>
            "You will own features end to end, pair with the platform team, and " <>
            "help shape our engineering practices."
      },
      tags: ["Elixir", "Backend", "Remote"]
    },
    %{
      attributes: %{
        "position" => "Full Stack Developer",
        "company_name" => "Contoso Software",
        "recruiter_name" => "Priya Raman",
        "job_posting_url" => "https://contoso.example.com/jobs/full-stack-developer",
        "description" =>
          "Work across a Laravel backend and a JavaScript frontend for a " <>
            "multi-tenant analytics product. Experience with billing flows is a plus."
      },
      tags: ["PHP", "Laravel", "Full-time"]
    },
    %{
      attributes: %{
        "position" => "Platform Engineer",
        "company_name" => "Fabrikam Cloud",
        "job_posting_url" => "https://fabrikam.example.com/careers/platform-engineer",
        "description" =>
          "Own the developer platform: CI pipelines, deployment tooling, and " <>
            "observability for a small but growing engineering organization."
      },
      tags: ["Elixir", "Backend", "Senior"]
    },
    %{
      attributes: %{
        "position" => "Frontend Engineer",
        "company_name" => "Initech Digital",
        "recruiter_name" => "Marco Bellini",
        "job_posting_url" => "https://initech.example.com/jobs/frontend-engineer",
        "description" =>
          "Build accessible, responsive interfaces for our customer portal. " <>
            "The team works in TypeScript and cares deeply about design quality."
      },
      tags: ["Frontend", "Remote", "Contract"]
    },
    %{
      attributes: %{
        "position" => "Data Engineer",
        "company_name" => "Umbrella Analytics",
        "recruiter_name" => "Alex Chen",
        "job_posting_url" => "https://umbrella.example.com/careers/data-engineer",
        "description" =>
          "Design batch and streaming pipelines that feed our reporting " <>
            "products. You will partner closely with analysts and product managers."
      },
      tags: ["Backend", "Startup"]
    }
  ]

  @switches [password: :string]

  @impl Mix.Task
  def run(args) do
    if "--help" in args or "-h" in args do
      Mix.shell().info(@moduledoc)
    else
      seed!(args)
    end
  end

  defp seed!(args) do
    Mix.Task.run("app.start")

    {opts, argv, invalid} = OptionParser.parse(args, strict: @switches)

    if invalid != [] do
      Mix.raise(
        "Invalid options: #{inspect(invalid)}. Usage: mix demo.seed [--password PASSWORD]"
      )
    end

    if argv != [] do
      Mix.raise("Usage: mix demo.seed [--password PASSWORD]")
    end

    user = fetch_or_create_user!(opts[:password])
    scope = Scope.for_user(user)

    Enum.each(@demo_applications, &seed_application!(scope, &1))

    Mix.shell().info("Seeded #{length(@demo_applications)} applications for #{user.email}")
  end

  defp fetch_or_create_user!(password) do
    case Accounts.get_user_by_email(@demo_email) do
      nil ->
        create_user!(password || prompt_password!())

      user ->
        Mix.shell().info("User #{user.email} already exists; reusing it")
        user
    end
  end

  defp create_user!(password) do
    case Accounts.create_user(%{email: @demo_email, password: password}) do
      {:ok, user} ->
        Mix.shell().info("Created user #{user.email}")
        user

      {:error, changeset} ->
        Mix.raise("Could not create user: #{format_errors(changeset)}")
    end
  end

  defp seed_application!(scope, %{attributes: attributes, tags: tags}) do
    case JobApplications.create_application_with_tags(scope, attributes, [], tags) do
      {:ok, application} ->
        Mix.shell().info(
          "Created application #{application.position} at #{application.company_name}"
        )

      {:error, changeset} ->
        Mix.raise(
          "Could not create application #{attributes["position"]}: #{format_errors(changeset)}"
        )
    end
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
      placeholder = "%{#{key}}"

      if String.contains?(acc, placeholder) do
        String.replace(acc, placeholder, to_string(value))
      else
        acc
      end
    end)
  end
end
