defmodule TrackMyJobExWeb.DashboardLiveTest do
  use TrackMyJobExWeb.ConnCase

  import Phoenix.LiveViewTest
  import TrackMyJobEx.AccountsFixtures

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
    assert has_element?(view, "#current-user-email", user.email)
    assert has_element?(view, "#log-out")
    refute has_element?(view, "#log-in")
  end
end
