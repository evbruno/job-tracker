defmodule TrackMyJobEx.TagsTest do
  use TrackMyJobEx.DataCase, async: false

  alias TrackMyJobEx.AccountsFixtures
  alias TrackMyJobEx.JobApplications
  alias TrackMyJobEx.JobApplications.ApplicationTag
  alias TrackMyJobEx.JobApplicationsFixtures
  alias TrackMyJobEx.Repo
  alias TrackMyJobEx.Tags
  alias TrackMyJobEx.TagsFixtures

  setup do
    %{scope: AccountsFixtures.user_scope_fixture()}
  end

  describe "create_tag/2" do
    test "creates a tag owned by the scope with a trimmed name", %{scope: scope} do
      assert {:ok, tag} = Tags.create_tag(scope, %{name: "  Elixir  "})

      assert tag.user_id == scope.user.id
      assert tag.name == "Elixir"
    end

    test "ignores a client-supplied user_id", %{scope: scope} do
      other_scope = AccountsFixtures.user_scope_fixture()

      assert {:ok, tag} =
               Tags.create_tag(scope, %{name: "Elixir", user_id: other_scope.user.id})

      assert tag.user_id == scope.user.id
    end

    test "requires a name and rejects blank names", %{scope: scope} do
      assert {:error, changeset} = Tags.create_tag(scope, %{name: "   "})
      assert errors_on(changeset).name != []
    end

    test "accepts 50 characters and rejects 51", %{scope: scope} do
      assert {:ok, _tag} = Tags.create_tag(scope, %{name: String.duplicate("n", 50)})

      assert {:error, changeset} =
               Tags.create_tag(scope, %{name: String.duplicate("n", 51)})

      assert errors_on(changeset).name != []
    end

    test "enforces case-insensitive uniqueness per user while preserving casing", %{scope: scope} do
      assert {:ok, tag} = Tags.create_tag(scope, %{name: "Elixir"})
      assert tag.name == "Elixir"

      assert {:error, changeset} = Tags.create_tag(scope, %{name: "elixir"})
      assert errors_on(changeset).name == ["has already been taken"]

      other_scope = AccountsFixtures.user_scope_fixture()
      assert {:ok, other_tag} = Tags.create_tag(other_scope, %{name: "elixir"})
      assert other_tag.name == "elixir"
      assert other_tag.user_id == other_scope.user.id
    end
  end

  describe "reads and isolation" do
    test "lists only the scope's tags ordered by name", %{scope: scope} do
      TagsFixtures.tag_fixture(scope, %{name: "Zeta"})
      TagsFixtures.tag_fixture(scope, %{name: "Alpha"})
      other_scope = AccountsFixtures.user_scope_fixture()
      TagsFixtures.tag_fixture(other_scope, %{name: "Other"})

      assert Tags.list_tags(scope) |> Enum.map(& &1.name) == ["Alpha", "Zeta"]
    end

    test "another user's tag behaves as not found", %{scope: scope} do
      other_scope = AccountsFixtures.user_scope_fixture()
      tag = TagsFixtures.tag_fixture(other_scope)

      assert Tags.get_tag(scope, tag.id) == nil
      assert Tags.get_tag(scope, "not-an-id") == nil

      assert_raise Ecto.NoResultsError, fn ->
        Tags.get_tag!(scope, tag.id)
      end
    end
  end

  describe "update_tag/3" do
    test "renames a tag and preserves the entered casing", %{scope: scope} do
      tag = TagsFixtures.tag_fixture(scope, %{name: "Elixir"})

      assert {:ok, updated} = Tags.update_tag(scope, tag, %{name: "  ELIXIR  "})
      assert updated.name == "ELIXIR"
    end

    test "rejects renaming to an existing name case-insensitively", %{scope: scope} do
      TagsFixtures.tag_fixture(scope, %{name: "Elixir"})
      tag = TagsFixtures.tag_fixture(scope, %{name: "Phoenix"})

      assert {:error, changeset} = Tags.update_tag(scope, tag, %{name: "elixir"})
      assert errors_on(changeset).name == ["has already been taken"]
    end

    test "does not let another user update the tag", %{scope: scope} do
      tag = TagsFixtures.tag_fixture(scope, %{name: "Elixir"})
      other_scope = AccountsFixtures.user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Tags.update_tag(other_scope, tag, %{name: "Hijacked"})
      end

      assert Tags.get_tag(scope, tag.id).name == "Elixir"
    end
  end

  describe "delete_tag/2" do
    test "hard-deletes the tag and removes its application links", %{scope: scope} do
      application = JobApplicationsFixtures.application_fixture(scope)
      tag = TagsFixtures.tag_fixture(scope)
      {:ok, _application_tag} = JobApplications.add_tag_to_application(scope, application, tag)

      assert {:ok, _deleted} = Tags.delete_tag(scope, tag)

      assert Tags.get_tag(scope, tag.id) == nil
      assert Repo.aggregate(ApplicationTag, :count) == 0
      assert JobApplications.get_application(scope, application.id)
    end

    test "does not let another user delete the tag", %{scope: scope} do
      tag = TagsFixtures.tag_fixture(scope)
      other_scope = AccountsFixtures.user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Tags.delete_tag(other_scope, tag)
      end

      assert Tags.get_tag(scope, tag.id)
    end
  end

  describe "get_tag_by_name/2" do
    test "finds a tag case-insensitively within the scope only", %{scope: scope} do
      tag = TagsFixtures.tag_fixture(scope, %{name: "Elixir"})

      assert Tags.get_tag_by_name(scope, "elixir").id == tag.id
      assert Tags.get_tag_by_name(scope, "  ELIXIR  ").id == tag.id

      other_scope = AccountsFixtures.user_scope_fixture()
      assert Tags.get_tag_by_name(other_scope, "Elixir") == nil
    end
  end

  describe "get_or_create_tag/2" do
    test "creates a new tag with a trimmed name", %{scope: scope} do
      assert {:ok, tag} = Tags.get_or_create_tag(scope, "  Remote  ")
      assert tag.name == "Remote"
      assert tag.user_id == scope.user.id
    end

    test "reuses an existing tag case-insensitively and preserves its casing", %{scope: scope} do
      existing = TagsFixtures.tag_fixture(scope, %{name: "Elixir"})

      assert {:ok, tag} = Tags.get_or_create_tag(scope, "elixir")
      assert tag.id == existing.id
      assert tag.name == "Elixir"
      assert Tags.list_tags(scope) |> length() == 1
    end

    test "does not reuse a tag owned by another user", %{scope: scope} do
      other_scope = AccountsFixtures.user_scope_fixture()
      TagsFixtures.tag_fixture(other_scope, %{name: "Elixir"})

      assert {:ok, tag} = Tags.get_or_create_tag(scope, "Elixir")
      assert tag.user_id == scope.user.id
    end

    test "rejects a blank name", %{scope: scope} do
      assert Tags.get_or_create_tag(scope, "   ") == {:error, :blank_name}
    end

    test "rejects a name over 50 characters", %{scope: scope} do
      assert {:error, %Ecto.Changeset{}} =
               Tags.get_or_create_tag(scope, String.duplicate("t", 51))
    end
  end
end
