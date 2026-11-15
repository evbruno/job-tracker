defmodule TrackMyJobExWeb.ApplicationLiveTest do
  use TrackMyJobExWeb.ConnCase

  import Phoenix.LiveViewTest
  import TrackMyJobEx.AccountsFixtures
  import TrackMyJobEx.JobApplicationsFixtures

  alias TrackMyJobEx.Accounts.Scope
  alias TrackMyJobEx.JobApplications

  describe "index" do
    test "lists only the current user's applications, newest first", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      older = application_fixture(scope, %{position: "Older role", company_name: "Acme"})
      newer = application_fixture(scope, %{position: "Newer role", company_name: "Beta"})

      other_user = user_fixture()
      other = application_fixture(Scope.for_user(other_user), %{position: "Other role"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications")

      assert has_element?(view, "#applications-#{older.id}")
      assert has_element?(view, "#applications-#{newer.id}")
      refute has_element?(view, "#applications-#{other.id}")
      refute has_element?(view, "#applications-empty")

      assert has_element?(
               view,
               "#applications-#{newer.id}-position",
               "Newer role"
             )

      assert has_element?(
               view,
               "#applications-#{newer.id}-company",
               "Beta"
             )

      assert has_element?(
               view,
               "#applications-#{newer.id}-status",
               "Interested"
             )

      assert has_element?(view, "#applications-#{newer.id}-created-at")

      document = LazyHTML.from_fragment(render(view))

      assert document
             |> LazyHTML.query("#applications a")
             |> LazyHTML.attribute("id") == [
               "applications-#{newer.id}",
               "applications-#{older.id}"
             ]
    end

    test "links each row to the application details page", %{conn: conn} do
      user = user_fixture()
      application = application_fixture(Scope.for_user(user))

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications")

      assert has_element?(
               view,
               "a#applications-#{application.id}[href='/applications/#{application.id}']"
             )
    end

    test "renders a clear empty state", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications")

      assert has_element?(view, "#applications-empty")
      assert has_element?(view, "#applications-empty", "No applications yet")
    end

    test "redirects anonymous visitors to the login page", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/applications")
    end
  end

  describe "show" do
    test "renders an application owned by the current user", %{conn: conn} do
      user = user_fixture()
      application = application_fixture(Scope.for_user(user), %{position: "Senior Engineer"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications/#{application.id}")

      assert has_element?(view, "#application-details")
      assert has_element?(view, "#application-status", "Interested")
    end

    test "another user's application behaves as not found", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      application = application_fixture(Scope.for_user(other_user))

      assert {:error, {:live_redirect, %{to: "/applications", flash: flash}}} =
               conn |> log_in_user(user) |> live(~p"/applications/#{application.id}")

      assert flash["error"] == "Application not found."
    end
  end

  describe "new" do
    test "renders the creation form", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications/new")

      assert has_element?(view, "#application-form")
      assert has_element?(view, "#job_application_position")
      assert has_element?(view, "#job_application_company_name")
      assert has_element?(view, "#job_application_recruiter_name")
      assert has_element?(view, "#job_application_job_posting_url")
      assert has_element?(view, "#job_application_description")
      assert has_element?(view, "#application-form-submit")
    end

    test "creates an application with the default Interested status", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications/new")

      params = %{
        "job_application" => %{
          "position" => "Senior Engineer",
          "description" => "Build the platform.",
          "job_posting_url" => "https://example.com/jobs/1",
          "company_name" => "Acme Corp",
          "recruiter_name" => "Jane Recruiter"
        }
      }

      view |> form("#application-form", params) |> render_submit()

      {path, flash} = assert_redirect(view)
      assert flash["info"] == "Application created successfully."

      application = JobApplications.list_applications(Scope.for_user(user)) |> List.first()
      assert path == ~p"/applications/#{application.id}"
      assert application.position == "Senior Engineer"
      assert application.company_name == "Acme Corp"
      assert application.recruiter_name == "Jane Recruiter"
      assert application.status.slug == "interested"
      assert application.user_id == user.id
    end

    test "renders validation errors inline", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications/new")

      html =
        view
        |> form("#application-form", %{
          "job_application" => %{"position" => "", "company_name" => ""}
        })
        |> render_submit()

      assert html =~ "can&#39;t be blank"
      assert has_element?(view, "#application-form")
    end

    test "rejects invalid job posting URLs", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications/new")

      html =
        view
        |> form("#application-form", %{
          "job_application" => %{
            "position" => "Engineer",
            "company_name" => "Acme",
            "job_posting_url" => "ftp://example.com"
          }
        })
        |> render_submit()

      assert html =~ "must be a valid http or https URL"
    end

    test "redirects anonymous visitors to the login page", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/applications/new")
    end
  end

  describe "edit" do
    test "renders the form with existing values and no status field", %{conn: conn} do
      user = user_fixture()

      application =
        application_fixture(Scope.for_user(user), %{
          position: "Original Position",
          company_name: "Original Co",
          recruiter_name: "Original Recruiter"
        })

      {:ok, view, _html} =
        conn |> log_in_user(user) |> live(~p"/applications/#{application.id}/edit")

      assert has_element?(view, "#application-form")
      assert has_element?(view, "#job_application_position[value='Original Position']")
      assert has_element?(view, "#job_application_company_name[value='Original Co']")
      assert has_element?(view, "#job_application_recruiter_name[value='Original Recruiter']")
      refute has_element?(view, "#job_application_status_id")
    end

    test "updates details, keeps the status, and redirects to details", %{conn: conn} do
      user = user_fixture()
      application = application_fixture(Scope.for_user(user), %{position: "Original"})

      {:ok, view, _html} =
        conn |> log_in_user(user) |> live(~p"/applications/#{application.id}/edit")

      params = %{
        "job_application" => %{
          "position" => "Updated Position",
          "company_name" => "Updated Co",
          "recruiter_name" => "New Recruiter"
        }
      }

      view |> form("#application-form", params) |> render_submit()

      {path, flash} = assert_redirect(view)
      assert path == ~p"/applications/#{application.id}"
      assert flash["info"] == "Application updated successfully."

      updated = JobApplications.get_application(Scope.for_user(user), application.id)
      assert updated.position == "Updated Position"
      assert updated.company_name == "Updated Co"
      assert updated.recruiter_name == "New Recruiter"
      assert updated.status_id == application.status_id
    end

    test "renders validation errors inline", %{conn: conn} do
      user = user_fixture()
      application = application_fixture(Scope.for_user(user))

      {:ok, view, _html} =
        conn |> log_in_user(user) |> live(~p"/applications/#{application.id}/edit")

      html =
        view
        |> form("#application-form", %{
          "job_application" => %{"position" => "", "company_name" => ""}
        })
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "another user's application behaves as not found", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      application = application_fixture(Scope.for_user(other_user))

      assert {:error, {:live_redirect, %{to: "/applications", flash: flash}}} =
               conn |> log_in_user(user) |> live(~p"/applications/#{application.id}/edit")

      assert flash["error"] == "Application not found."
    end

    test "redirects anonymous visitors to the login page", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} =
               live(conn, ~p"/applications/1/edit")
    end
  end
end
