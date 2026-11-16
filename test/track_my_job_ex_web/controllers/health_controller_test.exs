defmodule TrackMyJobExWeb.HealthControllerTest do
  use TrackMyJobExWeb.ConnCase

  describe "GET /health" do
    test "returns ok when the database is reachable", %{conn: conn} do
      conn = get(conn, "/health")

      assert conn.status == 200
      assert conn.resp_body == "ok\n"
      assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
    end

    test "does not require authentication or start a session", %{conn: conn} do
      conn = get(conn, "/health")

      assert conn.status == 200
      refute conn.resp_cookies["_track_my_job_ex_key"]
    end
  end
end
