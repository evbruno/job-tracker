defmodule TrackMyJobExWeb.DashboardLiveTest do
  use TrackMyJobExWeb.ConnCase

  import Phoenix.LiveViewTest
  import TrackMyJobEx.AccountsFixtures
  import TrackMyJobEx.JobApplicationsFixtures
  import TrackMyJobEx.TagsFixtures
  import TrackMyJobEx.ResumesFixtures

  alias TrackMyJobEx.Accounts.Scope
  alias TrackMyJobEx.JobApplications

  test "redirects anonymous visitors to the login page", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in", flash: flash}}} = live(conn, ~p"/")
    assert flash["error"] == "You must log in to access this page."
  end

  test "also redirects plain HTTP requests to the login page", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/users/log-in"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You must log in to access this page."
  end

  test "renders the authenticated landing page", %{conn: conn} do
    user = user_fixture()
    {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/")

    assert has_element?(view, "header a[href='/']", "Job Tracker")
    assert has_element?(view, "#dashboard")
    assert has_element?(view, "#dashboard-stats")
    assert has_element?(view, "#dashboard-applications-stat[href='/applications']")
    assert has_element?(view, "#dashboard-tags-stat[href='/tags']")
    assert has_element?(view, "#dashboard-resumes[href='/resumes']")
    assert has_element?(view, "#dashboard-resumes-stat[href='/resumes']")
    assert has_element?(view, "#dashboard-in-progress-stat[href='/applications']")
    assert has_element?(view, "#current-user-email", user.email)
    assert has_element?(view, "#log-out")
    refute has_element?(view, "#log-in")
  end

  test "shows user-scoped application, tag, resume, and in-progress counts", %{conn: conn} do
    user = user_fixture()
    scope = Scope.for_user(user)

    application_fixture(scope)
    accepted = application_fixture(scope, %{position: "Designer"})
    rejected = application_fixture(scope, %{position: "Analyst"})
    accepted_status_id = JobApplications.get_status_by_slug("accepted").id
    rejected_status_id = JobApplications.get_status_by_slug("rejected").id

    {:ok, _} =
      JobApplications.change_status(scope, accepted.id, %{status_id: accepted_status_id})

    {:ok, _} = JobApplications.change_status(scope, rejected.id, %{status_id: rejected_status_id})

    tag_fixture(scope)
    resume_fixture(scope)

    {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/")

    assert element(view, "#dashboard-applications-stat") |> render() =~ "3"
    assert element(view, "#dashboard-tags-stat") |> render() =~ "1"
    assert element(view, "#dashboard-resumes-stat") |> render() =~ "1"
    assert element(view, "#dashboard-in-progress-stat") |> render() =~ "2"
  end
end
