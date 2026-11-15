defmodule TrackMyJobExWeb.ApplicationLiveTest do
  use TrackMyJobExWeb.ConnCase

  import Ecto.Query
  import Phoenix.LiveViewTest
  import TrackMyJobEx.AccountsFixtures
  import TrackMyJobEx.JobApplicationsFixtures
  import TrackMyJobEx.TagsFixtures

  alias TrackMyJobEx.Accounts.Scope
  alias TrackMyJobEx.JobApplications
  alias TrackMyJobEx.JobApplications.JobApplication
  alias TrackMyJobEx.Repo

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
             |> LazyHTML.query("#applications > div")
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
               "#applications-#{application.id} a[href='/applications/#{application.id}']"
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

  describe "details" do
    test "displays the application fields, tags, timestamps, and empty history", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)

      application =
        application_fixture(scope, %{
          position: "Senior Engineer",
          description: "Build and maintain the platform.",
          job_posting_url: "https://example.com/jobs/1",
          company_name: "Acme Corp",
          recruiter_name: "Jane Recruiter"
        })

      tag = tag_fixture(scope, %{name: "Elixir"})
      {:ok, _application_tag} = JobApplications.add_tag_to_application(scope, application, tag)

      {:ok, view, _html} =
        conn |> log_in_user(user) |> live(~p"/applications/#{application.id}")

      assert has_element?(view, "#application-details")
      assert has_element?(view, "#application-company", "Acme Corp")
      assert has_element?(view, "#application-recruiter", "Jane Recruiter")
      assert has_element?(view, "#application-status", "Interested")
      assert has_element?(view, "#application-description", "Build and maintain the platform.")

      assert has_element?(
               view,
               "#application-job-posting-url[href='https://example.com/jobs/1'][target='_blank'][rel='noopener noreferrer']"
             )

      assert has_element?(view, "#tags-#{tag.id}", "Elixir")
      assert has_element?(view, "#application-created-at")
      assert has_element?(view, "#application-updated-at")
      assert has_element?(view, "#application-history-empty")
    end

    test "hides optional fields and shows fallbacks when absent", %{conn: conn} do
      user = user_fixture()

      application =
        application_fixture(Scope.for_user(user), %{
          recruiter_name: "",
          description: "",
          job_posting_url: ""
        })

      {:ok, view, _html} =
        conn |> log_in_user(user) |> live(~p"/applications/#{application.id}")

      refute has_element?(view, "#application-recruiter")
      assert has_element?(view, "#application-description-empty")
      assert has_element?(view, "#application-job-posting-url-empty")
      assert has_element?(view, "#application-tags-empty")
    end

    test "renders the status history when present", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      application = application_fixture(scope)

      history =
        status_history_fixture(application, %{
          changed_at: ~U[2026-11-14 12:00:00Z],
          notes: "Recruiter reached out"
        })

      {:ok, view, _html} =
        conn |> log_in_user(user) |> live(~p"/applications/#{application.id}")

      refute has_element?(view, "#application-history-empty")
      assert has_element?(view, "#history-#{history.id}")
      assert has_element?(view, "#history-#{history.id}-status", "Interested")
      assert has_element?(view, "#history-#{history.id}-changed-at", "2026-11-14 12:00 UTC")
    end

    test "renders an unsafe stored URL as plain text instead of a link", %{conn: conn} do
      user = user_fixture()
      application = application_fixture(Scope.for_user(user))

      from(a in JobApplication, where: a.id == ^application.id)
      |> Repo.update_all(set: [job_posting_url: "javascript:alert(1)"])

      {:ok, view, _html} =
        conn |> log_in_user(user) |> live(~p"/applications/#{application.id}")

      refute has_element?(view, "#application-job-posting-url")
      assert has_element?(view, "#application-job-posting-url-empty")
    end
  end

  describe "delete" do
    test "deletes from the index after confirmation and refreshes the list", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      application = application_fixture(scope)
      kept = application_fixture(scope, %{position: "Kept"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications")

      assert has_element?(view, "#delete-application-#{application.id}[data-confirm]")

      view |> element("#delete-application-#{application.id}") |> render_click()

      assert JobApplications.get_application(scope, application.id) == nil
      refute has_element?(view, "#applications-#{application.id}")
      assert has_element?(view, "#applications-#{kept.id}")
      assert has_element?(view, "#flash-info", "Application deleted.")
    end

    test "shows the empty state after deleting the last application", %{conn: conn} do
      user = user_fixture()
      application = application_fixture(Scope.for_user(user))

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications")

      view |> element("#delete-application-#{application.id}") |> render_click()

      assert has_element?(view, "#applications-empty")
    end

    test "deletes from the details page and redirects to the list", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      application = application_fixture(scope)

      {:ok, view, _html} =
        conn |> log_in_user(user) |> live(~p"/applications/#{application.id}")

      assert has_element?(view, "#delete-application[data-confirm]")

      view |> element("#delete-application") |> render_click()

      {path, flash} = assert_redirect(view)
      assert path == "/applications"
      assert flash["info"] == "Application deleted."
      assert JobApplications.get_application(scope, application.id) == nil
    end

    test "does not delete another user's application by id", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      other_application = application_fixture(Scope.for_user(other_user))

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications")

      view |> render_click("delete", %{"id" => other_application.id})

      assert JobApplications.get_application(Scope.for_user(other_user), other_application.id)
      assert has_element?(view, "#flash-error", "Application not found.")
    end
  end

  describe "company and recruiter fields" do
    test "trims values submitted through the creation form", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications/new")

      view
      |> form("#application-form", %{
        "job_application" => %{
          "position" => "  Senior Engineer  ",
          "company_name" => "  Acme Corp  ",
          "recruiter_name" => "  Jane Recruiter  "
        }
      })
      |> render_submit()

      application = JobApplications.list_applications(scope) |> List.first()
      assert application.position == "Senior Engineer"
      assert application.company_name == "Acme Corp"
      assert application.recruiter_name == "Jane Recruiter"
    end

    test "stores a blank recruiter as NULL through the creation form", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications/new")

      view
      |> form("#application-form", %{
        "job_application" => %{
          "position" => "Engineer",
          "company_name" => "Acme Corp",
          "recruiter_name" => "   "
        }
      })
      |> render_submit()

      assert JobApplications.list_applications(scope)
             |> List.first()
             |> Map.fetch!(:recruiter_name) == nil
    end

    test "trims values and clears a blank recruiter through the edit form", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      application = application_fixture(scope, %{recruiter_name: "Original Recruiter"})

      {:ok, view, _html} =
        conn |> log_in_user(user) |> live(~p"/applications/#{application.id}/edit")

      view
      |> form("#application-form", %{
        "job_application" => %{
          "position" => "  Updated Position  ",
          "company_name" => "  Updated Co  ",
          "recruiter_name" => "   "
        }
      })
      |> render_submit()

      updated = JobApplications.get_application(scope, application.id)
      assert updated.position == "Updated Position"
      assert updated.company_name == "Updated Co"
      assert updated.recruiter_name == nil
    end

    test "renders company and recruiter as plain text inputs with limits", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications/new")

      assert has_element?(
               view,
               "input#job_application_company_name[type='text'][maxlength='255']"
             )

      assert has_element?(
               view,
               "input#job_application_recruiter_name[type='text'][maxlength='255']"
             )
    end
  end

  describe "company and recruiter suggestions" do
    test "populates datalists from the current user's values only", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)

      application_fixture(scope, %{
        company_name: "Acme Corp",
        recruiter_name: "Zoe Recruiter"
      })

      application_fixture(scope, %{
        company_name: "acme corp",
        recruiter_name: "amy recruiter"
      })

      application_fixture(scope, %{company_name: "Beta Inc", recruiter_name: "   "})

      other_user = user_fixture()

      application_fixture(Scope.for_user(other_user), %{
        company_name: "Other Co",
        recruiter_name: "Other Recruiter"
      })

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications/new")

      assert has_element?(view, "#job_application_company_name[list='company-suggestions']")
      assert has_element?(view, "#job_application_recruiter_name[list='recruiter-suggestions']")

      document = LazyHTML.from_fragment(render(view))

      assert document
             |> LazyHTML.query("#company-suggestions option")
             |> LazyHTML.attribute("value") == ["Acme Corp", "Beta Inc"]

      assert document
             |> LazyHTML.query("#recruiter-suggestions option")
             |> LazyHTML.attribute("value") == ["amy recruiter", "Zoe Recruiter"]

      refute has_element?(view, "#company-suggestions option[value='Other Co']")
      refute has_element?(view, "#recruiter-suggestions option[value='Other Recruiter']")
    end

    test "also populates the suggestions on the edit form", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      application = application_fixture(scope)

      application_fixture(scope, %{
        company_name: "Suggested Co",
        recruiter_name: "Suggested Recruiter"
      })

      {:ok, view, _html} =
        conn |> log_in_user(user) |> live(~p"/applications/#{application.id}/edit")

      assert has_element?(view, "#company-suggestions option[value='Suggested Co']")
      assert has_element?(view, "#recruiter-suggestions option[value='Suggested Recruiter']")
    end
  end
end
