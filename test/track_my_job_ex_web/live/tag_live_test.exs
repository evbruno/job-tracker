defmodule TrackMyJobExWeb.TagLiveTest do
  use TrackMyJobExWeb.ConnCase

  import Phoenix.LiveViewTest
  import TrackMyJobEx.AccountsFixtures
  import TrackMyJobEx.JobApplicationsFixtures
  import TrackMyJobEx.TagsFixtures

  alias TrackMyJobEx.Accounts.Scope
  alias TrackMyJobEx.JobApplications
  alias TrackMyJobEx.Tags

  describe "index" do
    test "lists only the current user's tags ordered by name", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      zeta = tag_fixture(scope, %{name: "Zeta"})
      alpha = tag_fixture(scope, %{name: "Alpha"})

      other_user = user_fixture()
      other = tag_fixture(Scope.for_user(other_user), %{name: "Other"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/tags")

      assert has_element?(view, "#tags-#{alpha.id}", "Alpha")
      assert has_element?(view, "#tags-#{zeta.id}", "Zeta")
      refute has_element?(view, "#tags-#{other.id}")
      refute has_element?(view, "#tags-empty")

      document = LazyHTML.from_fragment(render(view))

      assert document
             |> LazyHTML.query("#tags > div")
             |> LazyHTML.attribute("id") == ["tags-#{alpha.id}", "tags-#{zeta.id}"]
    end

    test "renders an empty state", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/tags")

      assert has_element?(view, "#tags-empty")
    end

    test "redirects anonymous visitors to the login page", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/tags")
    end
  end

  describe "rename" do
    test "renames a tag and trims the value", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      tag = tag_fixture(scope, %{name: "Elixir"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/tags")

      view |> element("#edit-tag-#{tag.id}") |> render_click()
      assert has_element?(view, "#rename-tag-#{tag.id}")

      view
      |> form("#rename-tag-#{tag.id}", %{"tag" => %{"name" => "  Updated  "}})
      |> render_submit()

      assert Tags.get_tag(scope, tag.id).name == "Updated"
      assert has_element?(view, "#tag-name-#{tag.id}", "Updated")
      assert has_element?(view, "#flash-info", "Tag renamed.")
    end

    test "rejects a duplicate name case-insensitively and keeps the form open", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      tag_fixture(scope, %{name: "Elixir"})
      tag = tag_fixture(scope, %{name: "Phoenix"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/tags")

      view |> element("#edit-tag-#{tag.id}") |> render_click()

      html =
        view
        |> form("#rename-tag-#{tag.id}", %{"tag" => %{"name" => "elixir"}})
        |> render_submit()

      assert html =~ "has already been taken"
      assert Tags.get_tag(scope, tag.id).name == "Phoenix"
      assert has_element?(view, "#rename-tag-#{tag.id}")
    end

    test "does not rename another user's tag", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      other_tag = tag_fixture(Scope.for_user(other_user), %{name: "Original"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/tags")

      view
      |> render_click("rename", %{
        "tag" => %{"id" => to_string(other_tag.id), "name" => "Hijacked"}
      })

      assert Tags.get_tag(Scope.for_user(other_user), other_tag.id).name == "Original"
      assert has_element?(view, "#flash-error", "Tag not found.")
    end

    test "can cancel renaming", %{conn: conn} do
      user = user_fixture()
      tag = tag_fixture(Scope.for_user(user), %{name: "Elixir"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/tags")

      view |> element("#edit-tag-#{tag.id}") |> render_click()
      assert has_element?(view, "#rename-tag-#{tag.id}")

      view |> element("#cancel-edit-tag-#{tag.id}") |> render_click()

      refute has_element?(view, "#rename-tag-#{tag.id}")
      assert has_element?(view, "#tag-name-#{tag.id}", "Elixir")
    end
  end

  describe "delete" do
    test "deletes a tag after confirmation and leaves applications intact", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      application = application_fixture(scope)
      tag = tag_fixture(scope, %{name: "Elixir"})
      {:ok, _application_tag} = JobApplications.add_tag_to_application(scope, application, tag)

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/tags")

      assert has_element?(view, "#delete-tag-#{tag.id}[data-confirm]")

      view |> element("#delete-tag-#{tag.id}") |> render_click()

      assert Tags.get_tag(scope, tag.id) == nil
      assert JobApplications.get_application(scope, application.id)
      assert JobApplications.list_application_tags(scope, application) == []

      refute has_element?(view, "#tags-#{tag.id}")
      assert has_element?(view, "#flash-info", "Tag deleted.")
    end

    test "does not delete another user's tag", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      other_tag = tag_fixture(Scope.for_user(other_user), %{name: "Original"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/tags")

      view |> render_click("delete", %{"id" => to_string(other_tag.id)})

      assert Tags.get_tag(Scope.for_user(other_user), other_tag.id)
      assert has_element?(view, "#flash-error", "Tag not found.")
    end
  end
end
