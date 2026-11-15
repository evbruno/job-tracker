defmodule TrackMyJobExWeb.DashboardLiveTest do
  use TrackMyJobExWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders the dashboard shell for anonymous visitors", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "header a[href='/']", "Job Tracker")
    assert has_element?(view, "#dashboard")
    assert has_element?(view, "#counter", "0")
    assert has_element?(view, "#log-in")
    refute has_element?(view, "#log-out")
  end

  test "shows the signed-in user and logout control", %{conn: conn} do
    user = TrackMyJobEx.AccountsFixtures.user_fixture()

    {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/")

    assert has_element?(view, "#current-user-email", user.email)
    assert has_element?(view, "#log-out")
    refute has_element?(view, "#log-in")
  end

  test "increments and resets the counter", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view |> element("#increment") |> render_click()
    view |> element("#increment") |> render_click()
    assert has_element?(view, "#counter", "2")

    view |> element("#decrement") |> render_click()
    assert has_element?(view, "#counter", "1")

    view |> element("#reset") |> render_click()
    assert has_element?(view, "#counter", "0")
  end

  test "the counter never goes below zero", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view |> element("#decrement") |> render_click()
    assert has_element?(view, "#counter", "0")
  end
end
