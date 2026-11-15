defmodule TrackMyJobExWeb.DashboardLiveTest do
  use TrackMyJobExWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders the dashboard shell", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "header a[href='/']", "Job Tracker")
    assert has_element?(view, "#dashboard")
    assert has_element?(view, "#counter", "0")
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
