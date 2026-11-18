defmodule TrackMyJobExWeb.EndToEndTest do
  @moduledoc """
  End-to-end coverage of the critical workflow through the real router.

  This test uses two independently authenticated connections so tenant
  isolation is exercised the same way it is in production, not through a shared
  session helper.
  """

  use TrackMyJobExWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest
  import TrackMyJobEx.AccountsFixtures
  import TrackMyJobEx.JobApplicationsFixtures

  alias TrackMyJobEx.Accounts.Scope
  alias TrackMyJobEx.JobApplications
  alias TrackMyJobEx.JobApplications.ApplicationStatusHistory
  alias TrackMyJobEx.JobApplications.ApplicationTag
  alias TrackMyJobEx.Repo
  alias TrackMyJobEx.Tags

  test "critical workflow: login, create, status, list, isolate, delete", %{conn: conn} do
    user = user_fixture()
    scope = Scope.for_user(user)

    conn = log_in_through_router(conn, user)

    # Create an application with company, recruiter, a posting URL, and tags.
    {:ok, new_view, _html} = live(conn, ~p"/applications/new")

    new_view
    |> form("#application-form", %{
      "job_application" => %{
        "position" => "Staff Engineer",
        "company_name" => "Acme Corp",
        "recruiter_name" => "Jane Recruiter",
        "job_posting_url" => "https://example.com/jobs/staff-engineer",
        "description" => "Platform team"
      },
      "new_tags" => "Elixir, Remote"
    })
    |> render_submit()

    {details_path, create_flash} = assert_redirect(new_view)
    assert create_flash["info"] == "Application created successfully."

    [application] = JobApplications.list_applications(scope)
    assert details_path == ~p"/applications/#{application.id}"
    assert application.status.slug == "interested"
    assert Enum.map(application.tags, & &1.name) |> Enum.sort() == ["Elixir", "Remote"]

    history = JobApplications.list_status_history(scope, application)
    assert length(history) == 1
    assert hd(history).new_status.slug == "interested"
    assert hd(history).previous_status == nil

    # Change the status with a note and verify the timeline.
    {:ok, show_view, _html} = live(conn, ~p"/applications/#{application.id}")
    applied = JobApplications.get_status_by_slug("applied")

    show_view
    |> form("#status-change-form", %{
      "status_change" => %{
        "status_id" => to_string(applied.id),
        "notes" => "Recruiter called to schedule screening"
      }
    })
    |> render_submit()

    assert has_element?(show_view, "#application-status", "Applied")
    assert has_element?(show_view, "#current-status-name", "Applied")
    assert has_element?(show_view, "#application-history-entries", "Recruiter called")

    history = JobApplications.list_status_history(scope, application)
    assert Enum.map(history, & &1.new_status.slug) == ["interested", "applied"]
    assert List.last(history).notes == "Recruiter called to schedule screening"

    # Add enough applications to exercise pagination.
    for index <- 1..25 do
      application_fixture(scope, %{
        position: "Bulk Engineer #{index}",
        company_name: "Bulk Co",
        recruiter_name: "Bulk Recruiter"
      })
    end

    {:ok, index_view, _html} = live(conn, ~p"/applications")

    assert has_element?(index_view, "#applications-range", "Showing 1–25 of 26 applications")
    assert has_element?(index_view, "#applications-page", "Page 1 of 2")
    assert has_element?(index_view, "#pagination-next[href='/applications?page=2']")

    render_patch(index_view, ~p"/applications?page=2")
    assert has_element?(index_view, "#applications-page", "Page 2 of 2")
    assert has_element?(index_view, "#applications-#{application.id}")

    # Search, filter by status/company/tags, and sort.
    index_view |> form("#application-filters", %{"q" => "Staff"}) |> render_change()
    assert_patch(index_view, ~p"/applications?q=Staff")
    assert has_element?(index_view, "#applications-#{application.id}")
    refute has_element?(index_view, "#applications-#{bulk_application_id(scope)}")

    index_view
    |> form("#application-filters", %{"q" => "", "status" => "applied"})
    |> render_change()

    assert_patch(index_view, ~p"/applications?status=applied")
    assert has_element?(index_view, "#applications-#{application.id}")

    index_view
    |> form("#application-filters", %{"status" => "", "company" => "Bulk Co"})
    |> render_change()

    assert has_element?(index_view, "#applications-page", "Page 1 of 1")
    refute has_element?(index_view, "#applications-#{application.id}")

    tags = JobApplications.list_application_tags(scope, application)
    elixir = Enum.find(tags, &(&1.name == "Elixir"))
    remote = Enum.find(tags, &(&1.name == "Remote"))

    index_view
    |> form("#application-filters", %{
      "company" => "",
      "tags" => [to_string(elixir.id), to_string(remote.id)]
    })
    |> render_change()

    assert has_element?(index_view, "#applications-#{application.id}")

    index_view
    |> form("#application-filters", %{"tags" => [], "sort" => "updated"})
    |> render_change()

    assert_patch(index_view, ~p"/applications?sort=updated")
    index_view |> element("#toggle-sort-direction") |> render_click()

    assert_patch(
      index_view,
      ~p"/applications?#{%{"sort" => "updated", "direction" => "asc"}}"
    )

    # A second user with an independent session cannot see or delete the record.
    other_user = user_fixture()
    other_conn = log_in_through_router(build_conn(), other_user)

    {:ok, other_index, _html} = live(other_conn, ~p"/applications")
    refute has_element?(other_index, "#applications-#{application.id}")

    other_index |> render_click("delete", %{"id" => application.id})
    assert has_element?(other_index, "#flash-error", "Application not found.")
    assert JobApplications.get_application(scope, application.id)

    assert {:error, {:live_redirect, %{to: "/applications", flash: flash}}} =
             live(other_conn, ~p"/applications/#{application.id}")

    assert flash["error"] == "Application not found."

    # Delete the application and verify database cascades.
    {:ok, delete_view, _html} = live(conn, ~p"/applications/#{application.id}")
    delete_view |> element("#delete-application") |> render_click()
    delete_view |> element("#delete-application-modal-confirm") |> render_click()

    {path, delete_flash} = assert_redirect(delete_view)
    assert path == ~p"/applications"
    assert delete_flash["info"] == "Application deleted."
    assert JobApplications.get_application(scope, application.id) == nil

    assert Repo.aggregate(
             from(h in ApplicationStatusHistory, where: h.application_id == ^application.id),
             :count
           ) == 0

    assert Repo.aggregate(
             from(at in ApplicationTag, where: at.application_id == ^application.id),
             :count
           ) == 0

    # Deleting the application never deletes its tags.
    surviving_tags = Tags.list_tags(scope)

    assert Enum.map(surviving_tags, & &1.id) |> Enum.sort() ==
             [elixir.id, remote.id] |> Enum.sort()
  end

  defp log_in_through_router(conn, user) do
    conn = get(conn, ~p"/users/log-in")
    assert html_response(conn, 200) =~ "Log in"

    conn =
      post(conn, ~p"/users/log-in", %{
        "user" => %{"email" => user.email, "password" => valid_user_password()}
      })

    assert redirected_to(conn) == ~p"/"
    conn
  end

  defp bulk_application_id(scope) do
    scope
    |> JobApplications.list_applications()
    |> Enum.find(&(&1.company_name == "Bulk Co"))
    |> Map.fetch!(:id)
  end
end
