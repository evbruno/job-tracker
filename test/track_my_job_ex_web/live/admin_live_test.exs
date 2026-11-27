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
      assert has_element?(view, "#new-user-temporary-password")
    end

    test "admin can create and toggle temporary-password users", %{conn: conn} do
      admin = user_fixture(%{is_admin: true})
      {:ok, view, _html} = conn |> log_in_user(admin) |> live(~p"/admin")

      view
      |> form("#create-user-form",
        user: %{
          email: "temporary@example.com",
          password: "a valid temporary password",
          temporary_password: "true"
        }
      )
      |> render_submit()

      user = TrackMyJobEx.Accounts.get_user_by_email("temporary@example.com")
      assert user.temporary_password
      assert has_element?(view, "#user-temporary-password-badge-#{user.id}")

      view |> element("#toggle-temporary-password-#{user.id}") |> render_click()
      refute TrackMyJobEx.Accounts.get_user_by_email(user.email).temporary_password
    end
  end
end
