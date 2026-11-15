defmodule TrackMyJobExWeb.RemovedAuthRoutesTest do
  @moduledoc """
  Regression tests that keep generator-provided account flows disabled.

  Public registration, password reset, email confirmation, magic-link login,
  and account settings are intentionally unavailable.
  """

  use TrackMyJobExWeb.ConnCase

  @removed_paths [
    "/users/register",
    "/users/reset-password",
    "/users/forgot-password",
    "/users/log-in/magic-token",
    "/users/settings",
    "/users/settings/confirm-email/some-token"
  ]

  test "removed authentication routes do not exist" do
    for path <- @removed_paths do
      conn = get(build_conn(), path)
      assert conn.status == 404
    end
  end

  test "removed authentication POST routes do not exist" do
    for path <- ["/users/register", "/users/reset-password", "/users/settings"] do
      conn = post(build_conn(), path, %{})
      assert conn.status == 404
    end
  end
end
