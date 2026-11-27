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

    test "shows the password-change prompt when requested", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in?change_password=true")
      assert has_element?(lv, "h1", "Choose a new password")
      assert has_element?(lv, "input[name='user[new_password]']")
      assert has_element?(lv, "input[name='user[new_password_confirmation]']")
    end

    test "redirects authenticated users to the dashboard", %{conn: conn} do
      user = user_fixture()

      assert {:error, {:live_redirect, %{to: "/"}}} =
               conn
               |> log_in_user(user)
               |> live(~p"/users/log-in")
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
