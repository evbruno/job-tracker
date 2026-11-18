defmodule TrackMyJobEx.ResumesTest do
  use TrackMyJobEx.DataCase, async: false

  import Ecto.Query

  alias TrackMyJobEx.AccountsFixtures
  alias TrackMyJobEx.Repo
  alias TrackMyJobEx.Resumes
  alias TrackMyJobEx.Resumes.Resume
  alias TrackMyJobEx.Resumes.ResumeTag
  alias TrackMyJobEx.ResumesFixtures
  alias TrackMyJobEx.Tags
  alias TrackMyJobEx.TagsFixtures

  setup do
    %{scope: AccountsFixtures.user_scope_fixture()}
  end

  describe "new_resume_changeset/2" do
    test "prefills the email from the signed-in user and ignores client ownership", %{
      scope: scope
    } do
      other_scope = AccountsFixtures.user_scope_fixture()

      changeset =
        Resumes.new_resume_changeset(scope, %{
          title: "Backend",
          body: "Body",
          user_id: other_scope.user.id
        })

      assert Ecto.Changeset.get_field(changeset, :email) == scope.user.email
      assert Ecto.Changeset.get_field(changeset, :user_id) == scope.user.id
    end

    test "lets the caller override the prefilled email", %{scope: scope} do
      changeset =
        Resumes.new_resume_changeset(scope, %{
          title: "Backend",
          body: "Body",
          email: "other@example.com"
        })

      assert Ecto.Changeset.get_field(changeset, :email) == "other@example.com"
    end
  end

  describe "create_resume/2" do
    test "creates an owned resume with trimmed text and nil optional fields", %{scope: scope} do
      assert {:ok, resume} =
               Resumes.create_resume(scope, %{
                 title: "  Backend  ",
                 body: "  Experience  ",
                 email: "  candidate@example.com  ",
                 full_name: "   ",
                 headline: "",
                 phone: "  ",
                 location: "",
                 linkedin_url: "   ",
                 github_url: "",
                 portfolio_url: "  "
               })

      assert resume.user_id == scope.user.id
      assert resume.title == "Backend"
      assert resume.body == "Experience"
      assert resume.email == "candidate@example.com"
      assert resume.full_name == nil
      assert resume.headline == nil
      assert resume.phone == nil
      assert resume.location == nil
      assert resume.linkedin_url == nil
      assert resume.github_url == nil
      assert resume.portfolio_url == nil
    end

    test "ignores a client-supplied user_id", %{scope: scope} do
      other_scope = AccountsFixtures.user_scope_fixture()

      assert {:ok, resume} =
               Resumes.create_resume(scope, %{
                 title: "Backend",
                 body: "Body",
                 email: "candidate@example.com",
                 user_id: other_scope.user.id
               })

      assert resume.user_id == scope.user.id
    end

    test "requires a title, body, and email", %{scope: scope} do
      assert {:error, changeset} =
               Resumes.create_resume(scope, %{title: " ", body: " ", email: " "})

      errors = errors_on(changeset)
      assert errors.title != []
      assert errors.body != []
      assert errors.email != []
    end

    test "validates the email format", %{scope: scope} do
      for email <- ["not-an-email", "two@@example.com", "has space@example.com", "a@b;c"] do
        assert {:error, changeset} =
                 Resumes.create_resume(scope, %{
                   title: "Backend",
                   body: "Body",
                   email: email
                 })

        assert errors_on(changeset).email != []
      end
    end

    test "enforces the title, body, and email length limits", %{scope: scope} do
      assert {:ok, _resume} =
               Resumes.create_resume(scope, %{
                 title: String.duplicate("t", 255),
                 body: String.duplicate("b", 50_000),
                 email: "candidate@example.com"
               })

      assert {:error, changeset} =
               Resumes.create_resume(scope, %{
                 title: String.duplicate("t", 256),
                 body: String.duplicate("b", 50_001),
                 email: String.duplicate("e", 250) <> "@example.com"
               })

      errors = errors_on(changeset)
      assert errors.title != []
      assert errors.body != []
      assert errors.email != []
    end

    test "validates optional URLs and accepts http and https", %{scope: scope} do
      attrs = ResumesFixtures.valid_resume_attributes()

      assert {:ok, _resume} =
               Resumes.create_resume(scope, %{
                 attrs
                 | linkedin_url: "http://www.linkedin.com/in/ada",
                   github_url: "https://github.com/ada",
                   portfolio_url: nil
               })

      for field <- [:linkedin_url, :github_url, :portfolio_url] do
        for value <- ["not a url", "example.com", "//example.com", "javascript:alert(1)"] do
          assert {:error, changeset} =
                   Resumes.create_resume(scope, Map.put(attrs, field, value))

          assert errors_on(changeset)[field] != []
        end
      end
    end
  end

  describe "listing and isolation" do
    test "lists only the scope's resumes, most recently updated first", %{scope: scope} do
      first = ResumesFixtures.resume_fixture(scope, %{title: "First"})
      second = ResumesFixtures.resume_fixture(scope, %{title: "Second"})

      other_scope = AccountsFixtures.user_scope_fixture()
      other = ResumesFixtures.resume_fixture(other_scope, %{title: "Other"})

      older = DateTime.add(DateTime.utc_now(:second), -3600)
      newer = DateTime.add(DateTime.utc_now(:second), -1800)
      set_updated_at(first, older)
      set_updated_at(second, newer)

      assert Resumes.list_resumes(scope) |> Enum.map(& &1.title) == ["Second", "First"]
      refute Enum.any?(Resumes.list_resumes(scope), &(&1.id == other.id))
    end

    test "preloads tags", %{scope: scope} do
      tag = TagsFixtures.tag_fixture(scope, %{name: "Elixir"})

      {:ok, resume} =
        Resumes.create_resume_with_tags(
          scope,
          ResumesFixtures.valid_resume_attributes(),
          [tag.id],
          []
        )

      assert [listed] = Resumes.list_resumes(scope)
      assert listed.id == resume.id
      assert Enum.map(listed.tags, & &1.name) == ["Elixir"]
    end

    test "another user's resume behaves as not found", %{scope: scope} do
      other_scope = AccountsFixtures.user_scope_fixture()
      resume = ResumesFixtures.resume_fixture(other_scope)

      assert Resumes.get_resume(scope, resume.id) == nil
      assert Resumes.get_resume(scope, "not-an-id") == nil

      assert_raise Ecto.NoResultsError, fn -> Resumes.get_resume!(scope, resume.id) end
      assert_raise Ecto.NoResultsError, fn -> Resumes.list_resume_tags(scope, resume.id) end
    end
  end

  describe "update_resume/3" do
    test "updates fields owned by the scope", %{scope: scope} do
      resume = ResumesFixtures.resume_fixture(scope)

      assert {:ok, updated} =
               Resumes.update_resume(scope, resume, %{
                 title: "  Updated  ",
                 email: "new@example.com"
               })

      assert updated.title == "Updated"
      assert updated.email == "new@example.com"
    end

    test "does not let another user update the resume", %{scope: scope} do
      resume = ResumesFixtures.resume_fixture(scope)
      other_scope = AccountsFixtures.user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Resumes.update_resume(other_scope, resume, %{title: "Hijacked"})
      end

      assert Resumes.get_resume(scope, resume.id).title == resume.title
    end
  end

  describe "resume tags" do
    test "creates a resume with existing and inline tags atomically", %{scope: scope} do
      existing = TagsFixtures.tag_fixture(scope, %{name: "Elixir"})

      assert {:ok, resume} =
               Resumes.create_resume_with_tags(
                 scope,
                 ResumesFixtures.valid_resume_attributes(),
                 [existing.id],
                 ["Remote", "elixir"]
               )

      assert resume.tags |> Enum.map(& &1.name) |> Enum.sort() == ["Elixir", "Remote"]
      assert length(Resumes.list_resume_tags(scope, resume)) == 2
    end

    test "accepts tag ids as strings", %{scope: scope} do
      tag = TagsFixtures.tag_fixture(scope)

      assert {:ok, resume} =
               Resumes.create_resume_with_tags(
                 scope,
                 ResumesFixtures.valid_resume_attributes(),
                 [to_string(tag.id)],
                 []
               )

      assert Enum.map(resume.tags, & &1.id) == [tag.id]
    end

    test "ignores blank inline tag names", %{scope: scope} do
      assert {:ok, resume} =
               Resumes.create_resume_with_tags(
                 scope,
                 ResumesFixtures.valid_resume_attributes(),
                 [],
                 ["", "  "]
               )

      assert resume.tags == []
    end

    test "rejects another user's tag and rolls back the resume", %{scope: scope} do
      other_scope = AccountsFixtures.user_scope_fixture()
      other_tag = TagsFixtures.tag_fixture(other_scope)

      assert {:error, changeset} =
               Resumes.create_resume_with_tags(
                 scope,
                 ResumesFixtures.valid_resume_attributes(),
                 [other_tag.id],
                 []
               )

      assert changeset.errors[:tags] != nil
      assert Resumes.list_resumes(scope) == []
    end

    test "rejects an invalid tag id", %{scope: scope} do
      assert {:error, changeset} =
               Resumes.create_resume_with_tags(
                 scope,
                 ResumesFixtures.valid_resume_attributes(),
                 ["not-an-id"],
                 []
               )

      assert changeset.errors[:tags] != nil
      assert Resumes.list_resumes(scope) == []
    end

    test "replaces tags on update and touches updated_at", %{scope: scope} do
      first = TagsFixtures.tag_fixture(scope, %{name: "Elixir"})
      second = TagsFixtures.tag_fixture(scope, %{name: "Remote"})

      {:ok, resume} =
        Resumes.create_resume_with_tags(
          scope,
          ResumesFixtures.valid_resume_attributes(),
          [first.id],
          []
        )

      old = DateTime.add(DateTime.utc_now(:second), -3600)
      set_updated_at(resume, old)

      assert {:ok, updated} =
               Resumes.update_resume_with_tags(
                 scope,
                 resume,
                 %{title: "Updated"},
                 [second.id],
                 []
               )

      assert updated.title == "Updated"
      assert updated.tags |> Enum.map(& &1.name) == ["Remote"]
      assert DateTime.compare(updated.updated_at, old) == :gt
    end

    test "rolls back field changes when an update tag is invalid", %{scope: scope} do
      resume = ResumesFixtures.resume_fixture(scope, %{title: "Original"})
      other_scope = AccountsFixtures.user_scope_fixture()
      other_tag = TagsFixtures.tag_fixture(other_scope)

      assert {:error, changeset} =
               Resumes.update_resume_with_tags(scope, resume, %{title: "Hijacked"}, [other_tag.id])

      assert changeset.errors[:tags] != nil
      assert Resumes.get_resume(scope, resume.id).title == "Original"
    end

    test "set_resume_tags/3 replaces the linked tags", %{scope: scope} do
      tag = TagsFixtures.tag_fixture(scope, %{name: "Elixir"})
      resume = ResumesFixtures.resume_fixture(scope)

      assert {:ok, updated} = Resumes.set_resume_tags(scope, resume, [tag.id])
      assert Enum.map(updated.tags, & &1.name) == ["Elixir"]

      assert {:ok, cleared} = Resumes.set_resume_tags(scope, resume, [])
      assert cleared.tags == []
    end

    test "does not let another user replace the tags", %{scope: scope} do
      resume = ResumesFixtures.resume_fixture(scope)
      other_scope = AccountsFixtures.user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Resumes.set_resume_tags(other_scope, resume, [])
      end
    end
  end

  describe "delete_resume/2" do
    test "hard-deletes the resume and its tag links but keeps tags", %{scope: scope} do
      tag = TagsFixtures.tag_fixture(scope)

      {:ok, resume} =
        Resumes.create_resume_with_tags(
          scope,
          ResumesFixtures.valid_resume_attributes(),
          [tag.id],
          []
        )

      assert {:ok, _deleted} = Resumes.delete_resume(scope, resume)

      assert Resumes.get_resume(scope, resume.id) == nil
      assert Repo.aggregate(ResumeTag, :count) == 0
      assert Tags.get_tag(scope, tag.id)
    end

    test "does not let another user delete the resume", %{scope: scope} do
      resume = ResumesFixtures.resume_fixture(scope)
      other_scope = AccountsFixtures.user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Resumes.delete_resume(other_scope, resume)
      end

      assert Resumes.get_resume(scope, resume.id)
    end

    test "deleting a tag removes it from resumes without deleting them", %{scope: scope} do
      tag = TagsFixtures.tag_fixture(scope)

      {:ok, resume} =
        Resumes.create_resume_with_tags(
          scope,
          ResumesFixtures.valid_resume_attributes(),
          [tag.id],
          []
        )

      assert {:ok, _deleted} = Tags.delete_tag(scope, tag)
      assert Repo.aggregate(ResumeTag, :count) == 0
      assert Resumes.get_resume(scope, resume.id)
    end
  end

  defp set_updated_at(%Resume{} = resume, datetime) do
    from(r in Resume, where: r.id == ^resume.id)
    |> Repo.update_all(set: [updated_at: datetime])
  end
end
