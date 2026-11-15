defmodule TrackMyJobExWeb.UserLive.LoginTest do
  use TrackMyJobExWeb.ConnCase

  import Phoenix.LiveViewTest
  import TrackMyJobEx.AccountsFixtures

  describe "login page" do
    test "renders the password login form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "Log in"
      assert html =~ "Password"
      refute html =~ "Sign up"
      refute html =~ "magic"
    end

    test "redirects if the user logs in with valid credentials", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form = form(lv, "#login_form", user: %{email: user.email, password: valid_user_password()})

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :user_token)
    end

    test "shows an error if credentials are invalid", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form", user: %{email: user.email, password: "invalid password"})

      render_submit(form)

      conn = follow_trigger_action(form, conn)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end
end
