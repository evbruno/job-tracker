defmodule TrackMyJobExWeb.AdminLiveTest do
  use TrackMyJobExWeb.ConnCase

  import Phoenix.LiveViewTest
  import TrackMyJobEx.AccountsFixtures

  describe "admin access" do
    test "redirects non-admin users", %{conn: conn} do
      user = user_fixture()

      {:error, {:live_redirect, %{to: "/"}}} =
        conn |> log_in_user(user) |> live(~p"/admin")
    end

    test "admin users can view the page", %{conn: conn} do
      user = user_fixture(%{is_admin: true})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/admin")

      assert has_element?(view, "#create-user")
    end
  end
end
