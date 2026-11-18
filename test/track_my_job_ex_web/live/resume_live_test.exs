defmodule TrackMyJobExWeb.ResumeLiveTest do
  use TrackMyJobExWeb.ConnCase

  import Ecto.Query
  import Phoenix.LiveViewTest
  import TrackMyJobEx.AccountsFixtures
  import TrackMyJobEx.ResumesFixtures
  import TrackMyJobEx.TagsFixtures

  alias TrackMyJobEx.Accounts.Scope
  alias TrackMyJobEx.Repo
  alias TrackMyJobEx.Resumes
  alias TrackMyJobEx.Resumes.Resume

  describe "index" do
    test "lists only the current user's resumes, most recently updated first", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      first = resume_fixture(scope, %{title: "First version"})
      second = resume_fixture(scope, %{title: "Second version"})

      other = resume_fixture(Scope.for_user(user_fixture()), %{title: "Other version"})

      set_updated_at(first, DateTime.add(DateTime.utc_now(:second), -3600))
      set_updated_at(second, DateTime.add(DateTime.utc_now(:second), -1800))

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/resumes")

      assert has_element?(view, "#resumes-#{first.id}", "First version")
      assert has_element?(view, "#resumes-#{second.id}", "Second version")
      refute has_element?(view, "#resumes-#{other.id}")
      refute has_element?(view, "#resumes-empty")
      assert has_element?(view, "#resumes-count", "2 resumes")

      document = LazyHTML.from_fragment(render(view))

      assert document
             |> LazyHTML.query("#resumes > div")
             |> LazyHTML.attribute("id") == [
               "resumes-#{second.id}",
               "resumes-#{first.id}"
             ]
    end

    test "shows tags on each row", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      tag = tag_fixture(scope, %{name: "Elixir"})

      resume = resume_fixture(scope, %{title: "Tagged"})
      {:ok, resume} = Resumes.set_resume_tags(scope, resume, [tag.id])

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/resumes")

      assert has_element?(view, "#resumes-#{resume.id}-tag-#{tag.id}", "Elixir")
    end

    test "renders an empty state", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/resumes")

      assert has_element?(view, "#resumes-empty")
      assert has_element?(view, "#resumes-empty", "No resumes yet")
    end

    test "is linked from the main navigation", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/resumes")

      assert has_element?(view, "#nav-resumes[href='/resumes']")
    end

    test "redirects anonymous visitors to the login page", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/resumes")
    end
  end

  describe "new" do
    test "renders the form with the email prefilled from the user", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/resumes/new")

      assert has_element?(view, "#resume-form")
      assert has_element?(view, "#resume_title")
      assert has_element?(view, "#resume_body")
      assert has_element?(view, "#resume_linkedin_url")
      assert has_element?(view, "#resume_github_url")
      assert has_element?(view, "#resume_portfolio_url")
      assert has_element?(view, "#resume-tag-ids")
      assert has_element?(view, "#resume-new-tags")
      assert has_element?(view, "#resume-form-submit")
      assert has_element?(view, ~s(#resume_email[value="#{user.email}"]))
    end

    test "creates a resume with selected and inline tags", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      tag = tag_fixture(scope, %{name: "Elixir"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/resumes/new")

      view
      |> render_submit("save", %{
        "resume" => %{
          "title" => "Backend 2026",
          "body" => "Experience\n- Built things.",
          "email" => user.email,
          "full_name" => "Ada Lovelace",
          "headline" => "Backend engineer"
        },
        "tag_ids" => [to_string(tag.id)],
        "new_tags" => "Remote, Startup"
      })

      {path, flash} = assert_redirect(view)
      assert flash["info"] == "Resume created successfully."

      resume = Resumes.list_resumes(scope) |> List.first()
      assert path == ~p"/resumes/#{resume.id}"
      assert resume.title == "Backend 2026"
      assert resume.user_id == user.id
      assert Enum.map(resume.tags, & &1.name) |> Enum.sort() == ["Elixir", "Remote", "Startup"]
    end

    test "renders validation errors without creating a resume", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/resumes/new")

      html =
        view
        |> render_submit("save", %{
          "resume" => %{"title" => "", "body" => "", "email" => "not-an-email"}
        })

      assert html =~ "blank"
      assert html =~ "must have the @ sign and no spaces"
      assert Resumes.list_resumes(scope) == []
    end

    test "rejects another user's tag id and leaves no resume behind", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      other_tag = tag_fixture(Scope.for_user(user_fixture()))

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/resumes/new")

      html =
        view
        |> render_submit("save", %{
          "resume" => %{
            "title" => "Backend",
            "body" => "Body",
            "email" => user.email
          },
          "tag_ids" => [to_string(other_tag.id)],
          "new_tags" => ""
        })

      assert html =~ "invalid or unknown tag"
      assert Resumes.list_resumes(scope) == []
      assert has_element?(view, "#resume-form")
    end
  end

  describe "show" do
    test "renders the resume details and safe links", %{conn: conn} do
      user = user_fixture()
      resume = resume_fixture(Scope.for_user(user), %{title: "Backend 2026"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/resumes/#{resume.id}")

      assert has_element?(view, "#resume-title", "Backend 2026")
      assert has_element?(view, "#resume-email", resume.email)
      assert has_element?(view, "#resume-body", "Built and maintained the platform")
      assert has_element?(view, "#resume-linkedin-url[href='#{resume.linkedin_url}']")
      assert has_element?(view, "#resume-github-url[href='#{resume.github_url}']")
      assert has_element?(view, "#resume-portfolio-url[href='#{resume.portfolio_url}']")
      assert has_element?(view, "#delete-resume")
    end

    test "shows placeholders for missing optional values", %{conn: conn} do
      user = user_fixture()

      resume =
        resume_fixture(Scope.for_user(user), %{
          phone: nil,
          location: nil,
          linkedin_url: nil,
          github_url: nil,
          portfolio_url: nil
        })

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/resumes/#{resume.id}")

      assert has_element?(view, "#resume-phone", "Not provided")
      assert has_element?(view, "#resume-location", "Not provided")
      assert has_element?(view, "#resume-linkedin-url-empty", "Not provided")
      assert has_element?(view, "#resume-github-url-empty", "Not provided")
      assert has_element?(view, "#resume-portfolio-url-empty", "Not provided")
    end

    test "another user's resume behaves as not found", %{conn: conn} do
      user = user_fixture()
      resume = resume_fixture(Scope.for_user(user_fixture()))

      assert {:error, {:live_redirect, %{to: "/resumes", flash: flash}}} =
               conn |> log_in_user(user) |> live(~p"/resumes/#{resume.id}")

      assert flash["error"] == "Resume not found."
    end

    test "deletes the resume after a confirmation", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      resume = resume_fixture(scope)

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/resumes/#{resume.id}")

      refute has_element?(view, "#delete-resume-modal")

      view |> element("#delete-resume") |> render_click()
      assert has_element?(view, "#delete-resume-modal")

      view |> element("#delete-resume-modal-confirm") |> render_click()

      {path, flash} = assert_redirect(view)
      assert path == ~p"/resumes"
      assert flash["info"] == "Resume deleted."
      assert Resumes.get_resume(scope, resume.id) == nil
    end
  end

  describe "edit" do
    test "renders selected tags and updates the resume", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      elixir = tag_fixture(scope, %{name: "Elixir"})
      remote = tag_fixture(scope, %{name: "Remote"})

      {:ok, resume} =
        Resumes.create_resume_with_tags(
          scope,
          valid_resume_attributes(),
          [elixir.id],
          []
        )

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/resumes/#{resume.id}/edit")

      assert has_element?(view, "#resume-tag-ids input[value='#{elixir.id}'][checked]")
      refute has_element?(view, "#resume-tag-ids input[value='#{remote.id}'][checked]")

      view
      |> render_submit("save", %{
        "resume" => %{"title" => "Updated version"},
        "tag_ids" => [to_string(remote.id)],
        "new_tags" => ""
      })

      {path, flash} = assert_redirect(view)
      assert flash["info"] == "Resume updated successfully."
      assert path == ~p"/resumes/#{resume.id}"

      updated = Resumes.get_resume(scope, resume.id)
      assert updated.title == "Updated version"
      assert Enum.map(updated.tags, & &1.name) == ["Remote"]
    end

    test "another user's resume behaves as not found", %{conn: conn} do
      user = user_fixture()
      resume = resume_fixture(Scope.for_user(user_fixture()))

      assert {:error, {:live_redirect, %{to: "/resumes", flash: flash}}} =
               conn |> log_in_user(user) |> live(~p"/resumes/#{resume.id}/edit")

      assert flash["error"] == "Resume not found."
    end
  end

  defp set_updated_at(%Resume{} = resume, datetime) do
    from(r in Resume, where: r.id == ^resume.id)
    |> Repo.update_all(set: [updated_at: datetime])
  end
end
