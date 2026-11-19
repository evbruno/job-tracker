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

  describe "index tags" do
    test "shows tags linked to each application", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      application = application_fixture(scope)
      tag = tag_fixture(scope, %{name: "Elixir"})
      {:ok, _application_tag} = JobApplications.add_tag_to_application(scope, application, tag)

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications")

      assert has_element?(view, "#applications-#{application.id}-tags")
      assert has_element?(view, "#applications-#{application.id}-tag-#{tag.id}", "Elixir")
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
    test "displays the application fields, tags, timestamps, and initial history", %{conn: conn} do
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

      assert [initial] = JobApplications.list_status_history(scope, application)
      refute has_element?(view, "#application-history-empty")
      assert has_element?(view, "#history-#{initial.id}-status", "Interested")
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

    test "renders the status history chronologically, oldest first", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      application = application_fixture(scope)
      applied = JobApplications.get_status_by_slug("applied")

      assert {:ok, _application} =
               JobApplications.change_status(scope, application, %{
                 status_id: applied.id,
                 notes: "Recruiter reached out"
               })

      assert [initial, latest] = JobApplications.list_status_history(scope, application)

      {:ok, view, _html} =
        conn |> log_in_user(user) |> live(~p"/applications/#{application.id}")

      refute has_element?(view, "#application-history-empty")
      assert has_element?(view, "#history-#{initial.id}-status", "Interested")
      assert has_element?(view, "#history-#{latest.id}-status", "Applied")
      assert has_element?(view, "#history-#{latest.id}-previous", "From Interested")
      assert has_element?(view, "#history-#{latest.id}-notes", "Recruiter reached out")

      document = LazyHTML.from_fragment(render(view))

      assert document
             |> LazyHTML.query("#application-history ol > li")
             |> LazyHTML.attribute("id") == [
               "history-#{initial.id}",
               "history-#{latest.id}"
             ]
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

  describe "status changes" do
    test "renders the status change form with every predefined status", %{conn: conn} do
      user = user_fixture()
      application = application_fixture(Scope.for_user(user))

      {:ok, view, _html} =
        conn |> log_in_user(user) |> live(~p"/applications/#{application.id}")

      assert has_element?(view, "#status-change-form")
      assert has_element?(view, "#status_change_status_id")
      assert has_element?(view, "#status_change_notes[maxlength='2000']")
      assert has_element?(view, "#status-change-submit")
      assert has_element?(view, "#current-status-name", "Interested")

      document = LazyHTML.from_fragment(render(view))

      assert document
             |> LazyHTML.query("#status_change_status_id option")
             |> LazyHTML.attribute("value") ==
               ["" | Enum.map(JobApplications.list_statuses(), &to_string(&1.id))]
    end

    test "changes the status with a note and appends to the timeline", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      application = application_fixture(scope)
      applied = JobApplications.get_status_by_slug("applied")

      {:ok, view, _html} =
        conn |> log_in_user(user) |> live(~p"/applications/#{application.id}")

      view
      |> form("#status-change-form", %{
        "status_change" => %{
          "status_id" => to_string(applied.id),
          "notes" => "  Phone screen scheduled  "
        }
      })
      |> render_submit()

      assert has_element?(view, "#flash-info", "Status updated.")
      assert has_element?(view, "#application-status", "Applied")
      assert has_element?(view, "#current-status-name", "Applied")

      history = JobApplications.list_status_history(scope, application)
      assert length(history) == 2
      latest = List.last(history)

      assert has_element?(view, "#history-#{latest.id}-status", "Applied")
      assert has_element?(view, "#history-#{latest.id}-previous", "From Interested")
      assert has_element?(view, "#history-#{latest.id}-notes", "Phone screen scheduled")

      assert JobApplications.get_application!(scope, application.id).status.slug == "applied"
    end

    test "rejects changing to the current status", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      application = application_fixture(scope)
      interested = JobApplications.get_status_by_slug("interested")

      {:ok, view, _html} =
        conn |> log_in_user(user) |> live(~p"/applications/#{application.id}")

      html =
        view
        |> form("#status-change-form", %{
          "status_change" => %{"status_id" => to_string(interested.id)}
        })
        |> render_submit()

      assert html =~ "is already the current status"
      assert has_element?(view, "#application-status", "Interested")
      assert length(JobApplications.list_status_history(scope, application)) == 1
    end

    test "rejects a missing status and overlong notes without changing anything", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      application = application_fixture(scope)
      applied = JobApplications.get_status_by_slug("applied")

      {:ok, view, _html} =
        conn |> log_in_user(user) |> live(~p"/applications/#{application.id}")

      missing_html =
        view
        |> form("#status-change-form", %{"status_change" => %{"status_id" => ""}})
        |> render_submit()

      assert missing_html =~ "can&#39;t be blank"

      notes_html =
        view
        |> form("#status-change-form", %{
          "status_change" => %{
            "status_id" => to_string(applied.id),
            "notes" => String.duplicate("n", 2_001)
          }
        })
        |> render_submit()

      assert notes_html =~ "should be at most 2000 character(s)"
      assert has_element?(view, "#application-status", "Interested")
      assert length(JobApplications.list_status_history(scope, application)) == 1
    end
  end

  describe "delete" do
    test "deletes from the index after confirmation and refreshes the list", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      application = application_fixture(scope)
      kept = application_fixture(scope, %{position: "Kept"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications")

      assert has_element?(view, "#delete-application-#{application.id}")

      view |> element("#delete-application-#{application.id}") |> render_click()
      assert has_element?(view, "#delete-application-modal")

      view |> element("#delete-application-modal-confirm") |> render_click()

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
      view |> element("#delete-application-modal-confirm") |> render_click()

      assert has_element?(view, "#applications-empty")
    end

    test "deletes from the details page and redirects to the list", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      application = application_fixture(scope)

      {:ok, view, _html} =
        conn |> log_in_user(user) |> live(~p"/applications/#{application.id}")

      assert has_element?(view, "#delete-application")

      view |> element("#delete-application") |> render_click()
      assert has_element?(view, "#delete-application-modal")
      view |> element("#delete-application-modal-confirm") |> render_click()

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

  describe "inline tags" do
    test "renders existing tag selection and inline tag inputs", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications/new")

      assert has_element?(view, "#application-tag-ids")
      assert has_element?(view, "#application-new-tags")
    end

    test "creates an application with selected and inline tags", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      tag = tag_fixture(scope, %{name: "Elixir"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications/new")

      params = %{
        "job_application" => %{
          "position" => "Senior Engineer",
          "company_name" => "Acme Corp"
        },
        "tag_ids" => [to_string(tag.id)],
        "new_tags" => "Remote, Startup"
      }

      view |> render_submit("save", params)
      {path, _flash} = assert_redirect(view)

      application = JobApplications.list_applications(scope) |> List.first()
      assert path == ~p"/applications/#{application.id}"

      assert JobApplications.list_application_tags(scope, application) |> Enum.map(& &1.name) == [
               "Elixir",
               "Remote",
               "Startup"
             ]

      {:ok, show, _html} =
        build_conn() |> log_in_user(user) |> live(~p"/applications/#{application.id}")

      assert has_element?(show, "#tags-#{tag.id}", "Elixir")
    end

    test "reuses an existing tag for an inline name case-insensitively", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      existing = tag_fixture(scope, %{name: "Elixir"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications/new")

      view
      |> render_submit("save", %{
        "job_application" => %{"position" => "Engineer", "company_name" => "Acme"},
        "tag_ids" => [],
        "new_tags" => "elixir"
      })

      application = JobApplications.list_applications(scope) |> List.first()
      tags = JobApplications.list_application_tags(scope, application)
      assert Enum.map(tags, & &1.id) == [existing.id]
      assert Enum.map(tags, & &1.name) == ["Elixir"]
    end

    test "rejects another user's tag id and leaves no application behind", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      other_scope = Scope.for_user(user_fixture())
      other_tag = tag_fixture(other_scope)

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications/new")

      html =
        view
        |> render_submit("save", %{
          "job_application" => %{"position" => "Engineer", "company_name" => "Acme"},
          "tag_ids" => [to_string(other_tag.id)],
          "new_tags" => ""
        })

      assert html =~ "invalid or unknown tag"
      assert JobApplications.list_applications(scope) == []
      assert has_element?(view, "#application-form")
    end
  end

  describe "edit tag associations" do
    test "preloads the application's tags as selected options", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      application = application_fixture(scope)
      tag = tag_fixture(scope, %{name: "Elixir"})
      {:ok, _application_tag} = JobApplications.add_tag_to_application(scope, application, tag)

      {:ok, view, _html} =
        conn |> log_in_user(user) |> live(~p"/applications/#{application.id}/edit")

      assert has_element?(view, "#application-tag-ids input[value='#{tag.id}'][checked]")
    end

    test "replaces and creates tags on save and shows them on details", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      application = application_fixture(scope)
      old_tag = tag_fixture(scope, %{name: "Old"})
      new_tag = tag_fixture(scope, %{name: "New"})

      {:ok, _application_tag} =
        JobApplications.add_tag_to_application(scope, application, old_tag)

      {:ok, view, _html} =
        conn |> log_in_user(user) |> live(~p"/applications/#{application.id}/edit")

      view
      |> render_submit("save", %{
        "job_application" => %{
          "position" => application.position,
          "company_name" => application.company_name
        },
        "tag_ids" => [to_string(new_tag.id)],
        "new_tags" => "Inline"
      })

      {path, _flash} = assert_redirect(view)
      assert path == ~p"/applications/#{application.id}"

      assert JobApplications.list_application_tags(scope, application) |> Enum.map(& &1.name) == [
               "Inline",
               "New"
             ]

      {:ok, show, _html} =
        build_conn() |> log_in_user(user) |> live(~p"/applications/#{application.id}")

      assert has_element?(show, "#tags-#{new_tag.id}", "New")
      refute has_element?(show, "#tags-#{old_tag.id}")
    end

    test "rejects another user's tag on edit without partial changes", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      application = application_fixture(scope, %{position: "Original"})
      own_tag = tag_fixture(scope, %{name: "Own"})

      {:ok, _application_tag} =
        JobApplications.add_tag_to_application(scope, application, own_tag)

      other_tag = tag_fixture(Scope.for_user(user_fixture()))

      {:ok, view, _html} =
        conn |> log_in_user(user) |> live(~p"/applications/#{application.id}/edit")

      html =
        view
        |> render_submit("save", %{
          "job_application" => %{
            "position" => "Hijacked",
            "company_name" => application.company_name
          },
          "tag_ids" => [to_string(other_tag.id)],
          "new_tags" => ""
        })

      assert html =~ "invalid or unknown tag"

      unchanged = JobApplications.get_application!(scope, application.id)
      assert unchanged.position == "Original"

      assert JobApplications.list_application_tags(scope, application) |> Enum.map(& &1.id) == [
               own_tag.id
             ]
    end
  end

  describe "index search and filters" do
    test "searches position and company case-insensitively and keeps state in the URL", %{
      conn: conn
    } do
      user = user_fixture()
      scope = Scope.for_user(user)

      engineer =
        application_fixture(scope, %{position: "Senior Engineer", company_name: "Acme Corp"})

      manager =
        application_fixture(scope, %{position: "Product Manager", company_name: "Beta Inc"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications")

      assert has_element?(view, "#applications-#{engineer.id}")
      assert has_element?(view, "#applications-#{manager.id}")

      view |> form("#application-filters", %{"q" => "SENIOR"}) |> render_change()
      assert_patch(view, ~p"/applications?q=SENIOR")

      assert has_element?(view, "#applications-#{engineer.id}")
      refute has_element?(view, "#applications-#{manager.id}")

      view |> form("#application-filters", %{"q" => "beta"}) |> render_change()
      assert_patch(view, ~p"/applications?q=beta")

      assert has_element?(view, "#applications-#{manager.id}")
      refute has_element?(view, "#applications-#{engineer.id}")
    end

    test "restores search, filter, and sort state from the URL", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)

      match =
        application_fixture(scope, %{position: "Senior Engineer", company_name: "Acme Corp"})

      _other = application_fixture(scope, %{position: "Manager", company_name: "Beta Inc"})

      applied = JobApplications.get_status_by_slug("applied")
      {:ok, _application} = JobApplications.change_status(scope, match, %{status_id: applied.id})

      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/applications?q=acme&status=applied&sort=updated&direction=asc")

      assert has_element?(view, "#filter-q[value='acme']")
      assert has_element?(view, "#filter-status option[value='applied'][selected]")
      assert has_element?(view, "#filter-sort option[value='updated'][selected]")
      assert has_element?(view, "#applications-#{match.id}")
      assert has_element?(view, "#toggle-sort-direction", "Least recently updated")
    end

    test "filters by status", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)

      interested = application_fixture(scope, %{position: "Interested role"})
      applied = application_fixture(scope, %{position: "Applied role"})
      change_status!(scope, applied, "applied")

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications")

      view |> form("#application-filters", %{"status" => "applied"}) |> render_change()
      assert_patch(view, ~p"/applications?status=applied")

      assert has_element?(view, "#applications-#{applied.id}")
      refute has_element?(view, "#applications-#{interested.id}")
    end

    test "filters by company and recruiter using the user's own dropdown values", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)

      acme = application_fixture(scope, %{company_name: "Acme Corp", recruiter_name: "Jane"})
      beta = application_fixture(scope, %{company_name: "Beta Inc", recruiter_name: "Bob"})

      other_user = user_fixture()

      application_fixture(Scope.for_user(other_user), %{
        company_name: "Other Co",
        recruiter_name: "Other Recruiter"
      })

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications")

      document = LazyHTML.from_fragment(render(view))

      assert document
             |> LazyHTML.query("#filter-company option")
             |> LazyHTML.attribute("value") == ["", "Acme Corp", "Beta Inc"]

      assert document
             |> LazyHTML.query("#filter-recruiter option")
             |> LazyHTML.attribute("value") == ["", "Bob", "Jane"]

      view |> form("#application-filters", %{"company" => "Beta Inc"}) |> render_change()
      assert_patch(view, ~p"/applications?#{%{"company" => "Beta Inc"}}")
      assert has_element?(view, "#applications-#{beta.id}")
      refute has_element?(view, "#applications-#{acme.id}")

      view
      |> form("#application-filters", %{"company" => "", "recruiter" => "Jane"})
      |> render_change()

      assert has_element?(view, "#applications-#{acme.id}")
      refute has_element?(view, "#applications-#{beta.id}")
    end

    test "filters by multiple tags with AND semantics", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)

      elixir = tag_fixture(scope, %{name: "Elixir"})
      remote = tag_fixture(scope, %{name: "Remote"})

      both = application_fixture(scope, %{position: "Both tags"})
      only_elixir = application_fixture(scope, %{position: "Only Elixir"})

      {:ok, _} = JobApplications.add_tag_to_application(scope, both, elixir)
      {:ok, _} = JobApplications.add_tag_to_application(scope, both, remote)
      {:ok, _} = JobApplications.add_tag_to_application(scope, only_elixir, elixir)

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications")

      params = %{"tags" => [to_string(elixir.id), to_string(remote.id)]}
      view |> form("#application-filters", params) |> render_change()

      assert_patch(
        view,
        ~p"/applications?#{%{"tags" => [to_string(elixir.id), to_string(remote.id)]}}"
      )

      assert has_element?(view, "#applications-#{both.id}")
      refute has_element?(view, "#applications-#{only_elixir.id}")
      assert has_element?(view, "#filter-tags input[value='#{elixir.id}'][checked]")
      assert has_element?(view, "#filter-tags input[value='#{remote.id}'][checked]")
    end

    test "shows a no-matches empty state with a clear-filters action", %{conn: conn} do
      user = user_fixture()
      application = application_fixture(Scope.for_user(user))

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications")

      view |> form("#application-filters", %{"q" => "nothing-matches"}) |> render_change()

      assert has_element?(view, "#applications-no-matches", "No matching applications")
      refute has_element?(view, "#applications-empty")
      refute has_element?(view, "#applications-#{application.id}")
      assert has_element?(view, "#clear-filters-empty[href='/applications']")

      render_patch(view, ~p"/applications")

      assert has_element?(view, "#applications-#{application.id}")
      refute has_element?(view, "#applications-no-matches")
    end

    test "keeps the current filters after deleting a matching application", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)

      matching = application_fixture(scope, %{position: "Acme Engineer", company_name: "Acme"})
      other = application_fixture(scope, %{position: "Beta Manager", company_name: "Beta"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications?q=acme")

      refute has_element?(view, "#applications-#{other.id}")
      view |> element("#delete-application-#{matching.id}") |> render_click()
      view |> element("#delete-application-modal-confirm") |> render_click()

      assert has_element?(view, "#applications-no-matches")
      refute has_element?(view, "#applications-#{other.id}")
      assert has_element?(view, "#filter-q[value='acme']")
    end
  end

  describe "index sorting" do
    test "sorts by created date and toggles direction", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)

      oldest = application_fixture(scope, %{position: "Oldest"})
      middle = application_fixture(scope, %{position: "Middle"})
      newest = application_fixture(scope, %{position: "Newest"})

      set_application_timestamps(oldest, ~U[2026-01-01 00:00:00Z], ~U[2026-01-01 00:00:00Z])
      set_application_timestamps(middle, ~U[2026-01-02 00:00:00Z], ~U[2026-01-02 00:00:00Z])
      set_application_timestamps(newest, ~U[2026-01-03 00:00:00Z], ~U[2026-01-03 00:00:00Z])

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications")

      assert index_ids(view) == [
               "applications-#{newest.id}",
               "applications-#{middle.id}",
               "applications-#{oldest.id}"
             ]

      view |> element("#toggle-sort-direction") |> render_click()
      assert_patch(view, ~p"/applications?direction=asc")

      assert index_ids(view) == [
               "applications-#{oldest.id}",
               "applications-#{middle.id}",
               "applications-#{newest.id}"
             ]
    end

    test "sorts by last update", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)

      first = application_fixture(scope, %{position: "First"})
      second = application_fixture(scope, %{position: "Second"})

      set_application_timestamps(first, ~U[2026-01-01 00:00:00Z], ~U[2026-01-02 00:00:00Z])
      set_application_timestamps(second, ~U[2026-01-02 00:00:00Z], ~U[2026-01-01 00:00:00Z])

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications")

      view |> form("#application-filters", %{"sort" => "updated"}) |> render_change()
      assert_patch(view, ~p"/applications?sort=updated")

      assert index_ids(view) == ["applications-#{first.id}", "applications-#{second.id}"]

      view |> element("#toggle-sort-direction") |> render_click()

      assert_patch(
        view,
        ~p"/applications?#{%{"sort" => "updated", "direction" => "asc"}}"
      )

      assert index_ids(view) == ["applications-#{second.id}", "applications-#{first.id}"]
    end
  end

  describe "index pagination" do
    test "shows 25 applications per page and navigates between pages", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)

      applications =
        for index <- 1..27 do
          application_fixture(scope, %{position: "Position #{index}"})
        end

      oldest = List.first(applications)
      newest = List.last(applications)

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications")

      assert length(index_ids(view)) == 25
      assert has_element?(view, "#applications-page", "Page 1 of 2")
      assert has_element?(view, "#applications-range", "Showing 1–25 of 27 applications")
      assert has_element?(view, "#applications-#{newest.id}")
      refute has_element?(view, "#applications-#{oldest.id}")
      assert has_element?(view, "#pagination-prev-disabled")
      assert has_element?(view, "#pagination-next[href='/applications?page=2']")

      render_patch(view, ~p"/applications?page=2")

      assert length(index_ids(view)) == 2
      assert has_element?(view, "#applications-page", "Page 2 of 2")
      assert has_element?(view, "#applications-#{oldest.id}")
      refute has_element?(view, "#applications-#{newest.id}")
      assert has_element?(view, "#pagination-prev[href='/applications']")
      assert has_element?(view, "#pagination-next-disabled")
    end

    test "keeps filters when navigating pages", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)

      for index <- 1..26 do
        application_fixture(scope, %{position: "Acme #{index}", company_name: "Acme Corp"})
      end

      _other = application_fixture(scope, %{position: "Beta", company_name: "Beta Inc"})

      {:ok, view, _html} =
        conn |> log_in_user(user) |> live(~p"/applications?company=Acme+Corp")

      assert has_element?(view, "#applications-page", "Page 1 of 2")

      assert has_element?(
               view,
               "#pagination-next[href='/applications?company=Acme+Corp&page=2']"
             )

      render_patch(view, ~p"/applications?company=Acme+Corp&page=2")

      assert has_element?(view, "#applications-page", "Page 2 of 2")
      assert length(index_ids(view)) == 1
    end
  end

  describe "index empty states" do
    test "shows the no-applications state and hides the filter bar", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications")

      assert has_element?(view, "#applications-empty", "No applications yet")
      refute has_element?(view, "#applications-no-matches")
      refute has_element?(view, "#application-filters")
      refute has_element?(view, "#applications-pagination")
    end
  end

  defp change_status!(scope, application, slug) do
    status = JobApplications.get_status_by_slug(slug)

    {:ok, _application} =
      JobApplications.change_status(scope, application, %{status_id: status.id})

    :ok
  end

  defp set_application_timestamps(application, inserted_at, updated_at) do
    from(a in JobApplication, where: a.id == ^application.id)
    |> Repo.update_all(set: [inserted_at: inserted_at, updated_at: updated_at])

    :ok
  end

  defp index_ids(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#applications > div")
    |> LazyHTML.attribute("id")
  end
end
