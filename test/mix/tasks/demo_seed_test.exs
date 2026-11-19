defmodule Mix.Tasks.Demo.SeedTest do
  use TrackMyJobEx.DataCase, async: false

  import ExUnit.CaptureIO
  import TrackMyJobEx.AccountsFixtures

  alias Mix.Tasks.Demo.Seed, as: DemoSeed
  alias TrackMyJobEx.Accounts
  alias TrackMyJobEx.Accounts.Scope
  alias TrackMyJobEx.JobApplications
  alias TrackMyJobEx.Tags

  describe "mix demo.seed" do
    test "creates the demo user and five applications" do
      output =
        capture_io(fn ->
          DemoSeed.run(["--password", valid_user_password()])
        end)

      assert output =~ "Created user demo@example.com"
      assert output =~ "Seeded 5 applications for demo@example.com"

      assert user = Accounts.get_user_by_email("demo@example.com")
      assert Accounts.get_user_by_email_and_password("demo@example.com", valid_user_password())

      applications = JobApplications.list_applications(Scope.for_user(user))
      assert length(applications) == 5

      companies = applications |> Enum.map(& &1.company_name) |> Enum.uniq()
      assert length(companies) == 5
    end

    test "creates every application with the Interested status and initial history" do
      capture_io(fn -> DemoSeed.run(["--password", valid_user_password()]) end)

      scope = demo_scope()

      for application <- JobApplications.list_applications(scope) do
        assert application.status.slug == "interested"

        assert [history] = JobApplications.list_status_history(scope, application)
        assert is_nil(history.previous_status_id)
        assert history.new_status_id == application.status_id
      end
    end

    test "links tags and reuses names shared across applications" do
      capture_io(fn -> DemoSeed.run(["--password", valid_user_password()]) end)

      scope = demo_scope()

      applications = JobApplications.list_applications(scope)
      assert Enum.all?(applications, fn application -> application.tags != [] end)

      tags = Tags.list_tags(scope)
      tag_names = Enum.map(tags, & &1.name)

      # "Backend" appears on three applications but is stored once per user.
      assert Enum.count(tag_names, &(&1 == "Backend")) == 1
      assert length(tag_names) == 10
      assert "Elixir" in tag_names
    end

    test "reuses an existing demo user instead of failing or prompting" do
      existing = user_fixture(%{email: "demo@example.com"})

      output =
        capture_io(fn ->
          # No --password and no prompt: an existing user must be reused silently.
          DemoSeed.run([])
        end)

      assert output =~ "already exists; reusing it"
      assert output =~ "Seeded 5 applications for demo@example.com"

      assert %{id: id} = Accounts.get_user_by_email("demo@example.com")
      assert id == existing.id
      assert length(JobApplications.list_applications(Scope.for_user(existing))) == 5
    end

    test "fails clearly on a short password" do
      capture_io(fn ->
        assert_raise Mix.Error, ~r/password should be at least 12 character/, fn ->
          DemoSeed.run(["--password", "short"])
        end
      end)

      assert is_nil(Accounts.get_user_by_email("demo@example.com"))
    end

    test "fails clearly on unknown options" do
      capture_io(fn ->
        assert_raise Mix.Error, ~r/Invalid options/, fn ->
          DemoSeed.run(["--unknown", "value"])
        end
      end)
    end

    test "fails clearly on unexpected arguments" do
      capture_io(fn ->
        assert_raise Mix.Error, ~r/Usage: mix demo.seed/, fn ->
          DemoSeed.run(["demo@example.com"])
        end
      end)
    end
  end

  defp demo_scope do
    "demo@example.com"
    |> Accounts.get_user_by_email()
    |> Scope.for_user()
  end
end
