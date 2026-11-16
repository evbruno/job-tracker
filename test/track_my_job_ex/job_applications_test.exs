defmodule TrackMyJobEx.JobApplicationsTest do
  use TrackMyJobEx.DataCase, async: false

  alias TrackMyJobEx.AccountsFixtures
  alias TrackMyJobEx.JobApplications
  alias TrackMyJobEx.JobApplications.ApplicationStatusHistory
  alias TrackMyJobEx.JobApplications.ApplicationTag
  alias TrackMyJobEx.JobApplications.JobApplication
  alias TrackMyJobEx.JobApplicationsFixtures
  alias TrackMyJobEx.Repo
  alias TrackMyJobEx.Tags
  alias TrackMyJobEx.Tags.Tag
  alias TrackMyJobEx.TagsFixtures

  setup do
    %{scope: AccountsFixtures.user_scope_fixture()}
  end

  describe "statuses" do
    test "the 13 predefined statuses are seeded and ordered" do
      statuses = JobApplications.list_statuses()

      assert Enum.map(statuses, & &1.slug) == ~w(
               interested applied screening interview technical_interview
               final_interview offer accepted declined rejected withdrawn failed
               on_hold
             )

      assert Enum.map(statuses, & &1.name) == [
               "Interested",
               "Applied",
               "Screening",
               "Interview",
               "Technical Interview",
               "Final Interview",
               "Offer",
               "Accepted",
               "Declined",
               "Rejected",
               "Withdrawn",
               "Failed",
               "On Hold"
             ]

      assert Enum.map(statuses, & &1.position) == Enum.to_list(1..13)
    end

    test "statuses can be looked up by id and slug" do
      interested = JobApplications.get_status_by_slug("interested")

      assert interested.name == "Interested"
      assert JobApplications.get_status(interested.id).slug == "interested"
      assert JobApplications.get_status("not-an-id") == nil
      assert JobApplications.get_status_by_slug("unknown") == nil
    end

    test "the default status is Interested" do
      assert JobApplications.default_status().slug == "interested"
    end
  end

  describe "create_application/2" do
    test "creates an application owned by the scope with Interested as default", %{scope: scope} do
      attrs = %{
        position: "  Senior Engineer  ",
        description: "Build things.",
        job_posting_url: "https://example.com/jobs/1",
        company_name: "  Acme Corp  ",
        recruiter_name: "  Jane Recruiter  "
      }

      assert {:ok, application} = JobApplications.create_application(scope, attrs)

      assert application.user_id == scope.user.id
      assert application.status_id == JobApplications.default_status().id
      assert application.position == "Senior Engineer"
      assert application.company_name == "Acme Corp"
      assert application.recruiter_name == "Jane Recruiter"
      assert application.description == "Build things."
      assert application.job_posting_url == "https://example.com/jobs/1"

      fetched = JobApplications.get_application(scope, application.id)
      assert fetched.status.slug == "interested"
    end

    test "stores blank recruiter and blank URL as NULL", %{scope: scope} do
      attrs =
        JobApplicationsFixtures.valid_application_attributes(%{
          recruiter_name: "   ",
          job_posting_url: ""
        })

      assert {:ok, application} = JobApplications.create_application(scope, attrs)
      assert application.recruiter_name == nil
      assert application.job_posting_url == nil
    end

    test "ignores client-supplied user_id and status_id", %{scope: scope} do
      other_scope = AccountsFixtures.user_scope_fixture()
      accepted = JobApplications.get_status_by_slug("accepted")

      attrs =
        JobApplicationsFixtures.valid_application_attributes(%{
          user_id: other_scope.user.id,
          status_id: accepted.id
        })

      assert {:ok, application} = JobApplications.create_application(scope, attrs)
      assert application.user_id == scope.user.id
      assert application.status_id == JobApplications.default_status().id
    end

    test "requires position and company name", %{scope: scope} do
      assert {:error, changeset} =
               JobApplications.create_application(scope, %{position: "  ", company_name: "  "})

      errors = errors_on(changeset)
      assert errors.position != []
      assert errors.company_name != []
    end

    test "accepts fields at their maximum lengths", %{scope: scope} do
      attrs = %{
        position: String.duplicate("p", 255),
        company_name: String.duplicate("c", 255),
        recruiter_name: String.duplicate("r", 255),
        description: String.duplicate("d", 20_000)
      }

      assert {:ok, _application} = JobApplications.create_application(scope, attrs)
    end

    test "rejects fields over their maximum lengths", %{scope: scope} do
      assert {:error, position_changeset} =
               JobApplications.create_application(scope, %{
                 position: String.duplicate("p", 256)
               })

      assert errors_on(position_changeset).position != []

      assert {:error, company_changeset} =
               JobApplications.create_application(scope, %{
                 company_name: String.duplicate("c", 256)
               })

      assert errors_on(company_changeset).company_name != []

      assert {:error, recruiter_changeset} =
               JobApplications.create_application(scope, %{
                 recruiter_name: String.duplicate("r", 256)
               })

      assert errors_on(recruiter_changeset).recruiter_name != []

      assert {:error, description_changeset} =
               JobApplications.create_application(scope, %{
                 description: String.duplicate("d", 20_001)
               })

      assert errors_on(description_changeset).description != []
    end

    test "accepts valid http and https URLs", %{scope: scope} do
      for url <- ["http://example.com", "https://example.com/jobs/1?q=elixir#top"] do
        attrs = JobApplicationsFixtures.valid_application_attributes(%{job_posting_url: url})

        assert {:ok, application} =
                 JobApplications.create_application(scope, attrs)

        assert application.job_posting_url == url
      end
    end

    test "rejects invalid job posting URLs", %{scope: scope} do
      for url <- ["ftp://example.com", "example.com", "http://", "javascript:alert(1)"] do
        attrs = JobApplicationsFixtures.valid_application_attributes(%{job_posting_url: url})

        assert {:error, changeset} =
                 JobApplications.create_application(scope, attrs)

        assert errors_on(changeset).job_posting_url == [
                 "must be a valid http or https URL"
               ]
      end
    end
  end

  describe "application reads and isolation" do
    test "lists only the scope's applications, newest first", %{scope: scope} do
      older = JobApplicationsFixtures.application_fixture(scope, %{position: "Older"})
      newer = JobApplicationsFixtures.application_fixture(scope, %{position: "Newer"})
      other_scope = AccountsFixtures.user_scope_fixture()
      JobApplicationsFixtures.application_fixture(other_scope)

      assert JobApplications.list_applications(scope) |> Enum.map(& &1.id) == [
               newer.id,
               older.id
             ]
    end

    test "another user's application behaves as not found", %{scope: scope} do
      other_scope = AccountsFixtures.user_scope_fixture()
      application = JobApplicationsFixtures.application_fixture(other_scope)

      assert JobApplications.get_application(scope, application.id) == nil
      assert JobApplications.get_application(scope, "not-an-id") == nil

      assert_raise Ecto.NoResultsError, fn ->
        JobApplications.get_application!(scope, application.id)
      end
    end
  end

  describe "update_application/3" do
    test "updates fields and normalizes them", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)

      assert {:ok, updated} =
               JobApplications.update_application(scope, application, %{
                 position: "  Staff Engineer  ",
                 company_name: "  New Co  ",
                 recruiter_name: "   "
               })

      assert updated.position == "Staff Engineer"
      assert updated.company_name == "New Co"
      assert updated.recruiter_name == nil
      assert updated.id == application.id
    end

    test "does not let another user update the application", %{scope: scope} do
      other_scope = AccountsFixtures.user_scope_fixture()
      application = JobApplicationsFixtures.application_fixture(scope, %{position: "Original"})

      assert_raise Ecto.NoResultsError, fn ->
        JobApplications.update_application(other_scope, application, %{position: "Hijacked"})
      end

      assert JobApplications.get_application(scope, application.id).position == "Original"
    end
  end

  describe "delete_application/2" do
    test "hard-deletes the application and cascades history and tag links", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)
      tag = TagsFixtures.tag_fixture(scope)
      {:ok, _application_tag} = JobApplications.add_tag_to_application(scope, application, tag)
      JobApplicationsFixtures.status_history_fixture(application)

      assert {:ok, _deleted} = JobApplications.delete_application(scope, application)

      assert JobApplications.get_application(scope, application.id) == nil
      assert Repo.aggregate(ApplicationStatusHistory, :count) == 0
      assert Repo.aggregate(ApplicationTag, :count) == 0

      assert Tags.get_tag(scope, tag.id).id == tag.id
    end

    test "does not let another user delete the application", %{scope: scope} do
      other_scope = AccountsFixtures.user_scope_fixture()
      application = JobApplicationsFixtures.application_fixture(scope)

      assert_raise Ecto.NoResultsError, fn ->
        JobApplications.delete_application(other_scope, application)
      end

      assert JobApplications.get_application(scope, application.id)
    end
  end

  describe "status history" do
    test "lists append-only history oldest first with statuses preloaded", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)
      interested = JobApplications.default_status()
      applied = JobApplications.get_status_by_slug("applied")

      second =
        JobApplicationsFixtures.status_history_fixture(application, %{
          previous_status_id: interested.id,
          new_status_id: applied.id,
          changed_at: ~U[2026-11-14 12:00:00Z],
          notes: "Heard back"
        })

      first =
        JobApplicationsFixtures.status_history_fixture(application, %{
          new_status_id: interested.id,
          changed_at: ~U[2026-11-13 12:00:00Z]
        })

      history = JobApplications.list_status_history(scope, application)

      assert Enum.map(history, & &1.id) == [first.id, second.id]
      assert Enum.at(history, 0).previous_status == nil
      assert Enum.at(history, 0).new_status.slug == "interested"
      assert Enum.at(history, 1).previous_status.slug == "interested"
      assert Enum.at(history, 1).new_status.slug == "applied"
      assert Enum.at(history, 1).notes == "Heard back"
    end

    test "rejects history notes over 2000 characters" do
      changeset =
        ApplicationStatusHistory.changeset(%ApplicationStatusHistory{}, %{
          new_status_id: JobApplications.default_status().id,
          changed_at: DateTime.utc_now(:second),
          notes: String.duplicate("n", 2_001)
        })

      refute changeset.valid?
      assert errors_on(changeset).notes != []
    end

    test "does not let another user read the history", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)
      JobApplicationsFixtures.status_history_fixture(application)
      other_scope = AccountsFixtures.user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        JobApplications.list_status_history(other_scope, application)
      end
    end
  end

  describe "tag associations" do
    test "links and lists tags, and updates the application timestamp", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)
      tag = TagsFixtures.tag_fixture(scope, %{name: "Elixir"})
      old = DateTime.add(DateTime.utc_now(:second), -86_400, :second)
      set_updated_at(application, old)

      assert {:ok, application_tag} =
               JobApplications.add_tag_to_application(scope, application, tag)

      assert application_tag.application_id == application.id
      assert application_tag.tag_id == tag.id

      assert JobApplications.list_application_tags(scope, application) |> Enum.map(& &1.id) == [
               tag.id
             ]

      assert DateTime.compare(reload(application).updated_at, old) == :gt
    end

    test "unlinks tags and updates the application timestamp", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)
      tag = TagsFixtures.tag_fixture(scope)
      {:ok, _application_tag} = JobApplications.add_tag_to_application(scope, application, tag)
      old = DateTime.add(DateTime.utc_now(:second), -86_400, :second)
      set_updated_at(application, old)

      assert {:ok, :ok} =
               JobApplications.remove_tag_from_application(scope, application, tag)

      assert JobApplications.list_application_tags(scope, application) == []
      assert DateTime.compare(reload(application).updated_at, old) == :gt
    end

    test "removing a tag that is not linked returns not found", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)
      tag = TagsFixtures.tag_fixture(scope)

      assert {:error, :not_found} =
               JobApplications.remove_tag_from_application(scope, application, tag)
    end

    test "rejects a duplicate link", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)
      tag = TagsFixtures.tag_fixture(scope)
      {:ok, _application_tag} = JobApplications.add_tag_to_application(scope, application, tag)

      assert {:error, %Ecto.Changeset{}} =
               JobApplications.add_tag_to_application(scope, application, tag)

      assert Repo.aggregate(ApplicationTag, :count) == 1
    end

    test "does not let another user read or associate with the application", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)
      tag = TagsFixtures.tag_fixture(scope)
      other_scope = AccountsFixtures.user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        JobApplications.list_application_tags(other_scope, application)
      end

      assert_raise Ecto.NoResultsError, fn ->
        JobApplications.add_tag_to_application(other_scope, application, tag)
      end

      assert_raise Ecto.NoResultsError, fn ->
        JobApplications.remove_tag_from_application(other_scope, application, tag)
      end

      assert Repo.aggregate(ApplicationTag, :count) == 0
    end

    test "does not let a user link another user's tag", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)
      other_scope = AccountsFixtures.user_scope_fixture()
      other_tag = TagsFixtures.tag_fixture(other_scope)

      assert_raise Ecto.NoResultsError, fn ->
        JobApplications.add_tag_to_application(scope, application, other_tag)
      end

      assert Repo.aggregate(ApplicationTag, :count) == 0
    end

    test "deleting a tag removes links only, leaving applications intact", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)
      tag = TagsFixtures.tag_fixture(scope)
      {:ok, _application_tag} = JobApplications.add_tag_to_application(scope, application, tag)

      assert {:ok, _deleted} = Tags.delete_tag(scope, tag)

      assert Repo.aggregate(ApplicationTag, :count) == 0
      assert JobApplications.get_application(scope, application.id)
    end
  end

  defp set_updated_at(application, timestamp) do
    from(application in JobApplication, where: application.id == ^application.id)
    |> Repo.update_all(set: [updated_at: timestamp])
  end

  defp reload(application) do
    Repo.get!(JobApplication, application.id)
  end

  describe "company and recruiter suggestions" do
    test "uses only the scope's values, de-duplicates case-insensitively, and sorts", %{
      scope: scope
    } do
      JobApplicationsFixtures.application_fixture(scope, %{
        company_name: "Acme Corp",
        recruiter_name: "Zoe Recruiter"
      })

      JobApplicationsFixtures.application_fixture(scope, %{
        company_name: "acme corp",
        recruiter_name: "amy recruiter"
      })

      JobApplicationsFixtures.application_fixture(scope, %{
        company_name: "Beta Inc",
        recruiter_name: "   "
      })

      other_scope = AccountsFixtures.user_scope_fixture()

      JobApplicationsFixtures.application_fixture(other_scope, %{
        company_name: "Other Co",
        recruiter_name: "Other Recruiter"
      })

      companies = JobApplications.list_company_suggestions(scope)
      recruiters = JobApplications.list_recruiter_suggestions(scope)

      assert Enum.map(companies, &String.downcase/1) == ["acme corp", "beta inc"]
      assert Enum.map(recruiters, &String.downcase/1) == ["amy recruiter", "zoe recruiter"]
      refute "Other Co" in companies
      refute "Other Recruiter" in recruiters
    end

    test "returns an empty list when the scope has no applications", %{scope: scope} do
      assert JobApplications.list_company_suggestions(scope) == []
      assert JobApplications.list_recruiter_suggestions(scope) == []
    end
  end

  describe "create_application_with_tags/4" do
    test "creates the application with selected and inline-created tags", %{scope: scope} do
      tag = TagsFixtures.tag_fixture(scope, %{name: "Elixir"})

      assert {:ok, application} =
               JobApplications.create_application_with_tags(
                 scope,
                 JobApplicationsFixtures.valid_application_attributes(),
                 [tag.id],
                 ["  Remote  ", "Startup"]
               )

      names = JobApplications.list_application_tags(scope, application) |> Enum.map(& &1.name)
      assert names == ["Elixir", "Remote", "Startup"]
    end

    test "reuses an existing tag for an inline name case-insensitively", %{scope: scope} do
      existing = TagsFixtures.tag_fixture(scope, %{name: "Elixir"})

      assert {:ok, application} =
               JobApplications.create_application_with_tags(
                 scope,
                 JobApplicationsFixtures.valid_application_attributes(),
                 [],
                 ["elixir"]
               )

      tags = JobApplications.list_application_tags(scope, application)
      assert Enum.map(tags, & &1.id) == [existing.id]
      assert Enum.map(tags, & &1.name) == ["Elixir"]
      assert Repo.aggregate(Tag, :count) == 1
    end

    test "ignores blank names and duplicate selected ids", %{scope: scope} do
      tag = TagsFixtures.tag_fixture(scope, %{name: "Elixir"})

      assert {:ok, application} =
               JobApplications.create_application_with_tags(
                 scope,
                 JobApplicationsFixtures.valid_application_attributes(),
                 [tag.id, tag.id],
                 ["   ", ""]
               )

      assert JobApplications.list_application_tags(scope, application) |> Enum.map(& &1.id) == [
               tag.id
             ]
    end

    test "rolls back the application when a tag belongs to another user", %{scope: scope} do
      other_scope = AccountsFixtures.user_scope_fixture()
      other_tag = TagsFixtures.tag_fixture(other_scope)

      assert {:error, changeset} =
               JobApplications.create_application_with_tags(
                 scope,
                 JobApplicationsFixtures.valid_application_attributes(),
                 [other_tag.id],
                 []
               )

      assert errors_on(changeset).tags == ["contain an invalid or unknown tag"]
      assert JobApplications.list_applications(scope) == []
      assert Repo.aggregate(ApplicationTag, :count) == 0
    end

    test "rolls back the application when an unknown tag id is submitted", %{scope: scope} do
      assert {:error, changeset} =
               JobApplications.create_application_with_tags(
                 scope,
                 JobApplicationsFixtures.valid_application_attributes(),
                 ["not-an-id"],
                 []
               )

      assert errors_on(changeset).tags != []
      assert JobApplications.list_applications(scope) == []
    end

    test "rolls back the application when an inline tag name is invalid", %{scope: scope} do
      assert {:error, changeset} =
               JobApplications.create_application_with_tags(
                 scope,
                 JobApplicationsFixtures.valid_application_attributes(),
                 [],
                 [String.duplicate("t", 51)]
               )

      assert errors_on(changeset).tags != []
      assert JobApplications.list_applications(scope) == []
      assert Repo.aggregate(Tag, :count) == 0
    end

    test "still returns application validation errors without creating anything", %{scope: scope} do
      assert {:error, changeset} =
               JobApplications.create_application_with_tags(scope, %{position: ""}, [], [])

      assert errors_on(changeset).position != []
      assert JobApplications.list_applications(scope) == []
    end
  end

  describe "update_application_with_tags/5 and set_application_tags/3" do
    test "updates fields, replaces tag links, and touches the timestamp", %{scope: scope} do
      first = TagsFixtures.tag_fixture(scope, %{name: "First"})
      second = TagsFixtures.tag_fixture(scope, %{name: "Second"})
      application = JobApplicationsFixtures.application_fixture(scope)
      {:ok, _application_tag} = JobApplications.add_tag_to_application(scope, application, first)
      old = DateTime.add(DateTime.utc_now(:second), -86_400, :second)
      set_updated_at(application, old)

      assert {:ok, updated} =
               JobApplications.update_application_with_tags(
                 scope,
                 application,
                 %{position: "Updated"},
                 [second.id],
                 ["Remote"]
               )

      assert updated.position == "Updated"

      assert JobApplications.list_application_tags(scope, application) |> Enum.map(& &1.name) == [
               "Remote",
               "Second"
             ]

      assert DateTime.compare(reload(application).updated_at, old) == :gt
    end

    test "set_application_tags/3 replaces the full tag set", %{scope: scope} do
      first = TagsFixtures.tag_fixture(scope, %{name: "First"})
      second = TagsFixtures.tag_fixture(scope, %{name: "Second"})
      application = JobApplicationsFixtures.application_fixture(scope)
      {:ok, _application_tag} = JobApplications.add_tag_to_application(scope, application, first)

      assert {:ok, _updated} =
               JobApplications.set_application_tags(scope, application, [second.id])

      assert JobApplications.list_application_tags(scope, application) |> Enum.map(& &1.id) == [
               second.id
             ]

      assert {:ok, _updated} = JobApplications.set_application_tags(scope, application, [])
      assert JobApplications.list_application_tags(scope, application) == []
    end

    test "rolls back field and tag changes when a tag belongs to another user", %{scope: scope} do
      first = TagsFixtures.tag_fixture(scope, %{name: "First"})
      application = JobApplicationsFixtures.application_fixture(scope, %{position: "Original"})
      {:ok, _application_tag} = JobApplications.add_tag_to_application(scope, application, first)
      other_scope = AccountsFixtures.user_scope_fixture()
      other_tag = TagsFixtures.tag_fixture(other_scope)

      assert {:error, changeset} =
               JobApplications.update_application_with_tags(
                 scope,
                 application,
                 %{position: "Hijacked"},
                 [other_tag.id],
                 []
               )

      assert errors_on(changeset).tags != []

      unchanged = JobApplications.get_application!(scope, application.id)
      assert unchanged.position == "Original"

      assert JobApplications.list_application_tags(scope, application) |> Enum.map(& &1.id) == [
               first.id
             ]
    end

    test "reuses an existing tag for an inline name on update", %{scope: scope} do
      existing = TagsFixtures.tag_fixture(scope, %{name: "Elixir"})
      application = JobApplicationsFixtures.application_fixture(scope)

      assert {:ok, _updated} =
               JobApplications.update_application_with_tags(
                 scope,
                 application,
                 %{},
                 [],
                 ["elixir"]
               )

      assert JobApplications.list_application_tags(scope, application) |> Enum.map(& &1.id) == [
               existing.id
             ]
    end

    test "does not let another user update or re-tag the application", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)
      other_scope = AccountsFixtures.user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        JobApplications.update_application_with_tags(
          other_scope,
          application,
          %{position: "Hijacked"},
          [],
          []
        )
      end

      assert JobApplications.get_application(scope, application.id).position != "Hijacked"
    end
  end
end
