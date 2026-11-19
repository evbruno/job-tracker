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
    test "the 14 predefined statuses are seeded and ordered" do
      statuses = JobApplications.list_statuses()

      assert Enum.map(statuses, & &1.slug) == ~w(
               interested applied screening interview technical_interview
               final_interview offer accepted declined rejected withdrawn failed
               on_hold ghosted
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
               "On Hold",
               "Ghosted"
             ]

      assert Enum.map(statuses, & &1.position) == Enum.to_list(1..14)
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

    test "creates the initial Interested history record atomically", %{scope: scope} do
      attrs = JobApplicationsFixtures.valid_application_attributes()

      assert {:ok, application} = JobApplications.create_application(scope, attrs)

      assert [entry] = JobApplications.list_status_history(scope, application)
      assert entry.previous_status == nil
      assert entry.previous_status_id == nil
      assert entry.new_status.slug == "interested"
      assert entry.notes == nil
      assert entry.changed_at == application.inserted_at
      assert Repo.aggregate(ApplicationStatusHistory, :count) == 1
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
      applied = JobApplications.get_status_by_slug("applied")
      interview = JobApplications.get_status_by_slug("interview")

      assert {:ok, _application} =
               JobApplications.change_status(scope, application, %{
                 status_id: applied.id,
                 notes: "Heard back"
               })

      assert {:ok, _application} =
               JobApplications.change_status(scope, application, %{
                 status_id: interview.id
               })

      history = JobApplications.list_status_history(scope, application)

      assert Enum.map(history, & &1.new_status.slug) == ["interested", "applied", "interview"]

      assert Enum.at(history, 0).previous_status == nil
      assert Enum.at(history, 0).new_status.slug == "interested"
      assert Enum.at(history, 1).previous_status.slug == "interested"
      assert Enum.at(history, 1).new_status.slug == "applied"
      assert Enum.at(history, 1).notes == "Heard back"
      assert Enum.at(history, 2).previous_status.slug == "applied"
      assert Enum.at(history, 2).new_status.slug == "interview"
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

  describe "change_status/4" do
    test "changes to any other status, appends history, and touches updated_at", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)
      old = DateTime.add(DateTime.utc_now(:second), -86_400, :second)
      set_updated_at(application, old)
      accepted = JobApplications.get_status_by_slug("accepted")

      assert {:ok, updated} =
               JobApplications.change_status(scope, application, %{
                 status_id: accepted.id,
                 notes: "  Signed the offer  "
               })

      assert updated.status_id == accepted.id
      assert updated.status.slug == "accepted"
      assert DateTime.compare(reload(application).updated_at, old) == :gt

      history = JobApplications.list_status_history(scope, application)
      assert length(history) == 2

      entry = List.last(history)
      assert entry.previous_status.slug == "interested"
      assert entry.new_status.slug == "accepted"
      assert entry.notes == "Signed the offer"
    end

    test "supports any-to-any transitions", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)

      for slug <- ~w(rejected technical_interview on_hold offer withdrawn interested) do
        status = JobApplications.get_status_by_slug(slug)

        assert {:ok, updated} =
                 JobApplications.change_status(scope, application, %{status_id: status.id})

        assert updated.status.slug == slug
      end

      history = JobApplications.list_status_history(scope, application)
      assert length(history) == 7

      assert Enum.map(history, & &1.new_status.slug) == [
               "interested",
               "rejected",
               "technical_interview",
               "on_hold",
               "offer",
               "withdrawn",
               "interested"
             ]

      assert Enum.map(Enum.drop(history, 1), & &1.previous_status.slug) == [
               "interested",
               "rejected",
               "technical_interview",
               "on_hold",
               "offer",
               "withdrawn"
             ]
    end

    test "rejects changing to the same status", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)

      assert {:error, changeset} =
               JobApplications.change_status(scope, application, %{
                 status_id: application.status_id
               })

      assert errors_on(changeset).status_id == ["is already the current status"]
      assert length(JobApplications.list_status_history(scope, application)) == 1
      assert reload(application).status_id == application.status_id
    end

    test "requires a status and rejects unknown status ids", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)

      assert {:error, missing_changeset} =
               JobApplications.change_status(scope, application, %{notes: "No status"})

      assert errors_on(missing_changeset).status_id == ["can't be blank"]

      assert {:error, unknown_changeset} =
               JobApplications.change_status(scope, application, %{status_id: 999_999})

      assert errors_on(unknown_changeset).status_id == ["is not a valid status"]

      assert length(JobApplications.list_status_history(scope, application)) == 1
      assert reload(application).status_id == application.status_id
    end

    test "trims notes, stores blank notes as nil, and accepts the maximum length", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)
      applied = JobApplications.get_status_by_slug("applied")
      screening = JobApplications.get_status_by_slug("screening")
      max_notes = String.duplicate("n", 2_000)

      assert {:ok, _updated} =
               JobApplications.change_status(scope, application, %{
                 status_id: applied.id,
                 notes: "  Phone screen scheduled  "
               })

      assert List.last(JobApplications.list_status_history(scope, application)).notes ==
               "Phone screen scheduled"

      assert {:ok, _updated} =
               JobApplications.change_status(scope, application, %{
                 status_id: screening.id,
                 notes: max_notes
               })

      assert List.last(JobApplications.list_status_history(scope, application)).notes == max_notes

      interview = JobApplications.get_status_by_slug("interview")

      assert {:ok, _updated} =
               JobApplications.change_status(scope, application, %{
                 status_id: interview.id,
                 notes: "   "
               })

      assert List.last(JobApplications.list_status_history(scope, application)).notes == nil
    end

    test "rejects notes over the maximum length without partial changes", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)
      applied = JobApplications.get_status_by_slug("applied")

      assert {:error, changeset} =
               JobApplications.change_status(scope, application, %{
                 status_id: applied.id,
                 notes: String.duplicate("n", 2_001)
               })

      assert errors_on(changeset).notes != []
      assert length(JobApplications.list_status_history(scope, application)) == 1
      assert reload(application).status_id == application.status_id
    end

    test "rolls back the application update when the history insert fails", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)
      applied = JobApplications.get_status_by_slug("applied")
      original_status_id = application.status_id

      Repo.query!("""
      CREATE TRIGGER application_status_histories_abort_insert
      BEFORE INSERT ON application_status_histories
      BEGIN
        SELECT RAISE(ABORT, 'forced history failure');
      END
      """)

      assert_raise Exqlite.Error, fn ->
        JobApplications.change_status(scope, application, %{status_id: applied.id})
      end

      assert reload(application).status_id == original_status_id
      assert length(JobApplications.list_status_history(scope, application)) == 1
    end

    test "does not let another user change the status", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)
      other_scope = AccountsFixtures.user_scope_fixture()
      applied = JobApplications.get_status_by_slug("applied")

      assert_raise Ecto.NoResultsError, fn ->
        JobApplications.change_status(other_scope, application, %{status_id: applied.id})
      end

      assert_raise Ecto.NoResultsError, fn ->
        JobApplications.change_status_changeset(other_scope, application)
      end

      assert reload(application).status_id == application.status_id
      assert length(JobApplications.list_status_history(scope, application)) == 1
    end

    test "has no API for updating or deleting history rows" do
      functions = JobApplications.__info__(:functions)

      refute :create_status_history in functions
      refute :update_status_history in functions
      refute :delete_status_history in functions
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

    test "does not let another user replace the application's tags", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)
      own_tag = TagsFixtures.tag_fixture(scope, %{name: "Own"})

      {:ok, _application_tag} =
        JobApplications.add_tag_to_application(scope, application, own_tag)

      other_scope = AccountsFixtures.user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        JobApplications.set_application_tags(other_scope, application, [own_tag.id])
      end

      assert JobApplications.list_application_tags(scope, application) |> Enum.map(& &1.id) == [
               own_tag.id
             ]
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

      assert [entry] = JobApplications.list_status_history(scope, application)
      assert entry.previous_status == nil
      assert entry.new_status.slug == "interested"
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
      assert Repo.aggregate(ApplicationStatusHistory, :count) == 0
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
      assert Repo.aggregate(ApplicationStatusHistory, :count) == 0
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
      assert Repo.aggregate(ApplicationStatusHistory, :count) == 0
      assert Repo.aggregate(Tag, :count) == 0
    end

    test "still returns application validation errors without creating anything", %{scope: scope} do
      assert {:error, changeset} =
               JobApplications.create_application_with_tags(scope, %{position: ""}, [], [])

      assert errors_on(changeset).position != []
      assert JobApplications.list_applications(scope) == []
      assert Repo.aggregate(ApplicationStatusHistory, :count) == 0
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

  describe "list_applications_filtered/2 search" do
    test "matches position and company partially and case-insensitively", %{scope: scope} do
      engineer = application_for(scope, "Senior Elixir Engineer", "Acme Corp")
      manager = application_for(scope, "Product Manager", "Beta Inc")

      assert application_ids(scope, %{"q" => "senior"}) == [engineer.id]
      assert application_ids(scope, %{"q" => "ENGINEER"}) == [engineer.id]
      assert application_ids(scope, %{"q" => "acme"}) == [engineer.id]
      assert application_ids(scope, %{"q" => "beta"}) == [manager.id]
      assert application_ids(scope, %{"q" => "manager"}) == [manager.id]
      assert application_ids(scope, %{"q" => "nobody"}) == []
    end

    test "treats LIKE wildcards in the search term literally", %{scope: scope} do
      percent = application_for(scope, "100% Remote", "Acme Corp")
      _engineer = application_for(scope, "Senior Engineer", "Beta Inc")

      assert application_ids(scope, %{"q" => "100%"}) == [percent.id]
      assert application_ids(scope, %{"q" => "%"}) == [percent.id]
      assert application_ids(scope, %{"q" => "_"}) == []
    end

    test "reports whether filters are active", %{scope: scope} do
      application_for(scope, "Engineer", "Acme Corp")

      refute JobApplications.list_applications_filtered(scope, %{}).filtered?
      refute JobApplications.list_applications_filtered(scope, %{"q" => "   "}).filtered?
      assert JobApplications.list_applications_filtered(scope, %{"q" => "acme"}).filtered?
    end
  end

  describe "list_applications_filtered/2 filters" do
    test "filters by status slug", %{scope: scope} do
      interested = application_for(scope, "Engineer", "Acme Corp")
      applied = application_for(scope, "Manager", "Beta Inc")
      applied_status = JobApplications.get_status_by_slug("applied")

      {:ok, _application} =
        JobApplications.change_status(scope, applied, %{status_id: applied_status.id})

      assert application_ids(scope, %{"status" => "applied"}) == [applied.id]
      assert application_ids(scope, %{"status" => "interested"}) == [interested.id]
      assert application_ids(scope, %{"status" => "not-a-status"}) == [applied.id, interested.id]
      assert application_ids(scope, %{"status" => ""}) == [applied.id, interested.id]
    end

    test "filters by company and recruiter case-insensitively", %{scope: scope} do
      acme = application_for(scope, "Engineer", "Acme Corp", "Jane Recruiter")
      beta = application_for(scope, "Manager", "Beta Inc", "Bob Recruiter")
      no_recruiter = application_for(scope, "Designer", "Gamma LLC", nil)

      assert application_ids(scope, %{"company" => "acme corp"}) == [acme.id]
      assert application_ids(scope, %{"company" => "ACME CORP"}) == [acme.id]
      assert application_ids(scope, %{"company" => "acme"}) == []
      assert application_ids(scope, %{"recruiter" => "jane recruiter"}) == [acme.id]
      assert application_ids(scope, %{"recruiter" => "bob recruiter"}) == [beta.id]

      assert application_ids(scope, %{"recruiter" => ""}) == [
               no_recruiter.id,
               beta.id,
               acme.id
             ]
    end

    test "filters by one tag", %{scope: scope} do
      elixir = TagsFixtures.tag_fixture(scope, %{name: "Elixir"})
      with_tag = application_for(scope, "Engineer", "Acme Corp")
      without_tag = application_for(scope, "Manager", "Beta Inc")
      {:ok, _application_tag} = JobApplications.add_tag_to_application(scope, with_tag, elixir)

      assert application_ids(scope, %{"tags" => [to_string(elixir.id)]}) == [with_tag.id]
      assert application_ids(scope, %{"tags" => "999999"}) == [without_tag.id, with_tag.id]
    end

    test "combines multiple tags with AND semantics", %{scope: scope} do
      elixir = TagsFixtures.tag_fixture(scope, %{name: "Elixir"})
      remote = TagsFixtures.tag_fixture(scope, %{name: "Remote"})
      both = application_for(scope, "Engineer", "Acme Corp")
      only_elixir = application_for(scope, "Manager", "Beta Inc")
      only_remote = application_for(scope, "Designer", "Gamma LLC")

      {:ok, _} = JobApplications.add_tag_to_application(scope, both, elixir)
      {:ok, _} = JobApplications.add_tag_to_application(scope, both, remote)
      {:ok, _} = JobApplications.add_tag_to_application(scope, only_elixir, elixir)
      {:ok, _} = JobApplications.add_tag_to_application(scope, only_remote, remote)

      params = %{"tags" => [to_string(elixir.id), to_string(remote.id)]}
      assert application_ids(scope, params) == [both.id]

      params = %{"tags" => "#{elixir.id},#{remote.id}"}
      assert application_ids(scope, params) == [both.id]
    end

    test "combines search and filters with AND", %{scope: scope} do
      elixir = TagsFixtures.tag_fixture(scope, %{name: "Elixir"})
      applied = JobApplications.get_status_by_slug("applied")

      match =
        application_for(scope, "Senior Engineer", "Acme Corp", "Jane Recruiter")

      {:ok, _} = JobApplications.add_tag_to_application(scope, match, elixir)
      {:ok, _} = JobApplications.change_status(scope, match, %{status_id: applied.id})

      _wrong_company = application_for(scope, "Senior Engineer", "Beta Inc", "Jane Recruiter")
      _wrong_status = application_for(scope, "Senior Engineer", "Acme Corp", "Jane Recruiter")

      params = %{
        "q" => "senior",
        "status" => "applied",
        "company" => "acme corp",
        "recruiter" => "jane recruiter",
        "tags" => [to_string(elixir.id)]
      }

      assert application_ids(scope, params) == [match.id]

      assert application_ids(scope, Map.put(params, "company", "beta inc")) == []
    end

    test "returns filter option values from the scope's own data only", %{scope: scope} do
      own_tag = TagsFixtures.tag_fixture(scope, %{name: "Elixir"})
      application_for(scope, "Engineer", "Acme Corp", "Jane Recruiter")

      other_scope = AccountsFixtures.user_scope_fixture()
      other_tag = TagsFixtures.tag_fixture(other_scope, %{name: "Scala"})

      application_for(other_scope, "Manager", "Other Co", "Other Recruiter")

      options = JobApplications.filter_options(scope)

      assert length(options.statuses) == 14
      assert options.companies == ["Acme Corp"]
      assert options.recruiters == ["Jane Recruiter"]
      assert Enum.map(options.tags, & &1.id) == [own_tag.id]
      refute other_tag.id in Enum.map(options.tags, & &1.id)
    end

    test "ignores invalid, unknown, and other-user tag parameters", %{scope: scope} do
      own = application_for(scope, "Engineer", "Acme Corp")
      other_scope = AccountsFixtures.user_scope_fixture()
      other_tag = TagsFixtures.tag_fixture(other_scope, %{name: "Scala"})
      other = application_for(other_scope, "Manager", "Other Co")

      result =
        JobApplications.list_applications_filtered(scope, %{
          "q" => nil,
          "status" => "bogus",
          "company" => "",
          "recruiter" => "  ",
          "tags" => ["not-an-id", to_string(other_tag.id)],
          "sort" => "bogus",
          "direction" => "sideways",
          "page" => "not-a-page"
        })

      assert Enum.map(result.entries, & &1.id) == [own.id]
      refute other.id in Enum.map(result.entries, & &1.id)

      assert result.filters == %{
               q: nil,
               status: nil,
               company: nil,
               recruiter: nil,
               tags: [],
               archived: :active,
               sort: "created",
               direction: "desc"
             }

      refute result.filtered?
      assert result.page == 1
    end
  end

  describe "list_applications_filtered/2 sorting" do
    test "defaults to created date, newest first", %{scope: scope} do
      oldest = application_for(scope, "Oldest", "Acme Corp")
      middle = application_for(scope, "Middle", "Acme Corp")
      newest = application_for(scope, "Newest", "Acme Corp")

      set_timestamps(oldest, ~U[2026-01-01 00:00:00Z], ~U[2026-01-05 00:00:00Z])
      set_timestamps(middle, ~U[2026-01-02 00:00:00Z], ~U[2026-01-04 00:00:00Z])
      set_timestamps(newest, ~U[2026-01-03 00:00:00Z], ~U[2026-01-06 00:00:00Z])

      assert application_ids(scope, %{}) == [newest.id, middle.id, oldest.id]

      assert application_ids(scope, %{"sort" => "created", "direction" => "asc"}) == [
               oldest.id,
               middle.id,
               newest.id
             ]

      assert application_ids(scope, %{"sort" => "created", "direction" => "desc"}) == [
               newest.id,
               middle.id,
               oldest.id
             ]
    end

    test "sorts by last update in both directions", %{scope: scope} do
      first = application_for(scope, "First", "Acme Corp")
      second = application_for(scope, "Second", "Acme Corp")
      third = application_for(scope, "Third", "Acme Corp")

      set_timestamps(first, ~U[2026-01-01 00:00:00Z], ~U[2026-01-07 00:00:00Z])
      set_timestamps(second, ~U[2026-01-03 00:00:00Z], ~U[2026-01-05 00:00:00Z])
      set_timestamps(third, ~U[2026-01-02 00:00:00Z], ~U[2026-01-06 00:00:00Z])

      assert application_ids(scope, %{"sort" => "updated", "direction" => "desc"}) == [
               first.id,
               third.id,
               second.id
             ]

      assert application_ids(scope, %{"sort" => "updated", "direction" => "asc"}) == [
               second.id,
               third.id,
               first.id
             ]
    end
  end

  describe "list_applications_filtered/2 pagination" do
    test "returns 25 applications per page with totals and clamping", %{scope: scope} do
      applications =
        for index <- 1..27 do
          application_for(scope, "Position #{index}", "Acme Corp")
        end

      first_page = JobApplications.list_applications_filtered(scope, %{})
      assert first_page.page_size == 25
      assert first_page.total_count == 27
      assert first_page.total_pages == 2
      assert first_page.page == 1
      assert length(first_page.entries) == 25

      second_page = JobApplications.list_applications_filtered(scope, %{"page" => "2"})
      assert second_page.page == 2
      assert length(second_page.entries) == 2

      assert Enum.sort(Enum.map(first_page.entries ++ second_page.entries, & &1.id)) ==
               Enum.sort(Enum.map(applications, & &1.id))

      clamped = JobApplications.list_applications_filtered(scope, %{"page" => "99"})
      assert clamped.page == 2
      assert length(clamped.entries) == 2

      assert JobApplications.list_applications_filtered(scope, %{"page" => "0"}).page == 1
      assert JobApplications.list_applications_filtered(scope, %{"page" => "-3"}).page == 1
    end

    test "keeps filters across pages", %{scope: scope} do
      for index <- 1..26 do
        application_for(scope, "Position #{index}", "Acme Corp")
      end

      application_for(scope, "Other", "Beta Inc")

      first_page =
        JobApplications.list_applications_filtered(scope, %{"company" => "acme corp"})

      second_page =
        JobApplications.list_applications_filtered(scope, %{
          "company" => "acme corp",
          "page" => "2"
        })

      assert first_page.total_count == 26
      assert first_page.total_pages == 2
      assert length(first_page.entries) == 25
      assert length(second_page.entries) == 1
      assert second_page.entries |> hd() |> Map.fetch!(:company_name) == "Acme Corp"
    end
  end

  describe "list_applications_filtered/2 isolation" do
    test "never returns another user's applications for any filter", %{scope: scope} do
      own = application_for(scope, "Senior Engineer", "Acme Corp", "Jane Recruiter")
      own_tag = TagsFixtures.tag_fixture(scope, %{name: "Elixir"})
      {:ok, _} = JobApplications.add_tag_to_application(scope, own, own_tag)

      other_scope = AccountsFixtures.user_scope_fixture()
      other = application_for(other_scope, "Senior Engineer", "Acme Corp", "Jane Recruiter")
      other_tag = TagsFixtures.tag_fixture(other_scope, %{name: "Elixir"})
      {:ok, _} = JobApplications.add_tag_to_application(other_scope, other, other_tag)

      params = %{
        "q" => "senior",
        "company" => "acme corp",
        "recruiter" => "jane recruiter",
        "tags" => [to_string(own_tag.id), to_string(other_tag.id)]
      }

      result = JobApplications.list_applications_filtered(scope, params)

      assert Enum.map(result.entries, & &1.id) == [own.id]
      assert result.total_count == 1
      refute other.id in Enum.map(result.entries, & &1.id)
    end

    test "another user's company, recruiter, and status values do not leak", %{scope: scope} do
      application_for(scope, "Engineer", "Acme Corp", "Jane Recruiter")
      other_scope = AccountsFixtures.user_scope_fixture()
      other = application_for(other_scope, "Manager", "Secret Co", "Secret Recruiter")
      applied = JobApplications.get_status_by_slug("applied")
      {:ok, _} = JobApplications.change_status(other_scope, other, %{status_id: applied.id})

      assert application_ids(scope, %{"company" => "secret co"}) == []
      assert application_ids(scope, %{"recruiter" => "secret recruiter"}) == []
      assert application_ids(scope, %{"status" => "applied"}) == []
    end

    test "filter_options only exposes the scope's own values", %{scope: scope} do
      application_for(scope, "Engineer", "Acme Corp", "Jane Recruiter")
      own_tag = TagsFixtures.tag_fixture(scope, %{name: "Own"})

      other_scope = AccountsFixtures.user_scope_fixture()
      application_for(other_scope, "Manager", "Secret Co", "Secret Recruiter")
      other_tag = TagsFixtures.tag_fixture(other_scope, %{name: "Secret"})

      options = JobApplications.filter_options(scope)

      assert options.companies == ["Acme Corp"]
      assert options.recruiters == ["Jane Recruiter"]
      assert Enum.map(options.tags, & &1.id) == [own_tag.id]
      refute other_tag.id in Enum.map(options.tags, & &1.id)
      assert Enum.map(options.statuses, & &1.slug) |> Enum.member?("interested")
    end
  end

  defp application_for(scope, position, company, recruiter \\ nil) do
    JobApplicationsFixtures.application_fixture(scope, %{
      position: position,
      company_name: company,
      recruiter_name: recruiter
    })
  end

  defp application_ids(scope, params) do
    scope
    |> JobApplications.list_applications_filtered(params)
    |> Map.fetch!(:entries)
    |> Enum.map(& &1.id)
  end

  defp set_timestamps(application, inserted_at, updated_at) do
    from(a in JobApplication, where: a.id == ^application.id)
    |> Repo.update_all(set: [inserted_at: inserted_at, updated_at: updated_at])

    :ok
  end
end
