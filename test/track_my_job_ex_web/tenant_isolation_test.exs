defmodule TrackMyJobExWeb.TenantIsolationTest do
  @moduledoc """
  Isolation tests that are possible before Phase 3 domain resources exist.

  These tests prove that two users can hold independent sessions, that each
  session resolves to its own user, and that protected routes reject anonymous
  requests. Record-level isolation tests for applications, tags, status history,
  and tag associations are added in Phase 3 once those resources exist.
  """

  use TrackMyJobExWeb.ConnCase

  import Phoenix.LiveViewTest
  import TrackMyJobEx.AccountsFixtures

  alias TrackMyJobEx.Accounts
  alias TrackMyJobEx.Accounts.Scope
  alias TrackMyJobExWeb.UserAuth

  describe "scope conventions" do
    test "wraps a user and is nil for anonymous callers" do
      user = user_fixture()

      assert %Scope{user: %{id: user_id}} = Scope.for_user(user)
      assert user_id == user.id
      assert Scope.for_user(nil) == nil
    end
  end

  describe "independent user sessions" do
    test "each session resolves to its own user" do
      user_a = user_fixture()
      user_b = user_fixture()

      token_a = Accounts.generate_user_session_token(user_a)
      token_b = Accounts.generate_user_session_token(user_b)

      assert {session_a, _} = Accounts.get_user_by_session_token(token_a)
      assert {session_b, _} = Accounts.get_user_by_session_token(token_b)

      assert session_a.id == user_a.id
      assert session_b.id == user_b.id
      refute session_a.id == session_b.id
    end

    test "logging out one user does not invalidate the other session" do
      user_a = user_fixture()
      user_b = user_fixture()

      conn_a = log_in_user(build_conn(), user_a)
      conn_b = log_in_user(build_conn(), user_b)
      token_a = get_session(conn_a, :user_token)
      token_b = get_session(conn_b, :user_token)

      conn_a = delete(conn_a, ~p"/users/log-out")

      assert redirected_to(conn_a) == ~p"/users/log-in"
      refute Accounts.get_user_by_session_token(token_a)
      assert {session_b, _} = Accounts.get_user_by_session_token(token_b)
      assert session_b.id == user_b.id
    end

    test "each authenticated dashboard only exposes its own user" do
      user_a = user_fixture()
      user_b = user_fixture()

      {:ok, view_a, _html} = build_conn() |> log_in_user(user_a) |> live(~p"/")
      {:ok, view_b, _html} = build_conn() |> log_in_user(user_b) |> live(~p"/")

      assert has_element?(view_a, "#current-user-email", user_a.email)
      refute has_element?(view_a, "#current-user-email", user_b.email)

      assert has_element?(view_b, "#current-user-email", user_b.email)
      refute has_element?(view_b, "#current-user-email", user_a.email)
    end
  end

  describe "protected routes" do
    test "anonymous HTTP requests are redirected" do
      conn = get(build_conn(), ~p"/")

      assert redirected_to(conn) == ~p"/users/log-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "anonymous LiveView mounts are halted by the router on_mount hook" do
      session = %{}

      socket = %Phoenix.LiveView.Socket{
        endpoint: TrackMyJobExWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      assert {:halt, halted_socket} =
               UserAuth.on_mount(:require_authenticated, %{}, session, socket)

      assert halted_socket.assigns.current_scope == nil

      assert Phoenix.Flash.get(halted_socket.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "a valid session can access the protected dashboard" do
      user = user_fixture()
      conn = log_in_user(build_conn(), user)

      assert {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "#dashboard")
    end
  end

  describe "log_in_user_fixture/1" do
    test "provisions an independent user and session for isolation tests" do
      context = log_in_user_fixture(%{conn: build_conn()})

      assert %{user: user, scope: %Scope{user: %{id: user_id}}, conn: conn} = context
      assert user_id == user.id
      assert get_session(conn, :user_token)
    end

    test "accepts an existing user" do
      user = user_fixture()
      context = log_in_user_fixture(%{conn: build_conn(), user: user})

      assert context.user.id == user.id
      assert context.scope.user.id == user.id
    end
  end
end
