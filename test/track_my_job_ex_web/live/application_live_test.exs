defmodule TrackMyJobExWeb.ApplicationLiveTest do
  use TrackMyJobExWeb.ConnCase

  import Phoenix.LiveViewTest
  import TrackMyJobEx.AccountsFixtures
  import TrackMyJobEx.JobApplicationsFixtures

  alias TrackMyJobEx.Accounts.Scope

  describe "index" do
    test "lists only the current user's applications, newest first", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)
      older = application_fixture(scope, %{position: "Older role", company_name: "Acme"})
      newer = application_fixture(scope, %{position: "Newer role", company_name: "Beta"})

      other_user = user_fixture()
      other = application_fixture(Scope.for_user(other_user), %{position: "Other role"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications")

      assert has_element?(view, "#applications-#{older.id}")
      assert has_element?(view, "#applications-#{newer.id}")
      refute has_element?(view, "#applications-#{other.id}")
      refute has_element?(view, "#applications-empty")

      assert has_element?(
               view,
               "#applications-#{newer.id}-position",
               "Newer role"
             )

      assert has_element?(
               view,
               "#applications-#{newer.id}-company",
               "Beta"
             )

      assert has_element?(
               view,
               "#applications-#{newer.id}-status",
               "Interested"
             )

      assert has_element?(view, "#applications-#{newer.id}-created-at")

      document = LazyHTML.from_fragment(render(view))

      assert document
             |> LazyHTML.query("#applications a")
             |> LazyHTML.attribute("id") == [
               "applications-#{newer.id}",
               "applications-#{older.id}"
             ]
    end

    test "links each row to the application details page", %{conn: conn} do
      user = user_fixture()
      application = application_fixture(Scope.for_user(user))

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications")

      assert has_element?(
               view,
               "a#applications-#{application.id}[href='/applications/#{application.id}']"
             )
    end

    test "renders a clear empty state", %{conn: conn} do
      user = user_fixture()

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications")

      assert has_element?(view, "#applications-empty")
      assert has_element?(view, "#applications-empty", "No applications yet")
    end

    test "redirects anonymous visitors to the login page", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/applications")
    end
  end

  describe "show" do
    test "renders an application owned by the current user", %{conn: conn} do
      user = user_fixture()
      application = application_fixture(Scope.for_user(user), %{position: "Senior Engineer"})

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/applications/#{application.id}")

      assert has_element?(view, "#application-details")
      assert has_element?(view, "#application-status", "Interested")
    end

    test "another user's application behaves as not found", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      application = application_fixture(Scope.for_user(other_user))

      assert {:error, {:live_redirect, %{to: "/applications", flash: flash}}} =
               conn |> log_in_user(user) |> live(~p"/applications/#{application.id}")

      assert flash["error"] == "Application not found."
    end
  end
end
