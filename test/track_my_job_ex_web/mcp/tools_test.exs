defmodule TrackMyJobExWeb.MCP.ToolsTest do
  use TrackMyJobEx.DataCase, async: false

  import Phantom.Test

  alias TrackMyJobEx.AccountsFixtures
  alias TrackMyJobEx.JobApplicationsFixtures
  alias TrackMyJobEx.ResumesFixtures
  alias TrackMyJobEx.TagsFixtures
  alias TrackMyJobExWeb.MCP.Router

  setup do
    Phantom.Test.start(router: Router)
    scope = AccountsFixtures.user_scope_fixture()
    other_scope = AccountsFixtures.user_scope_fixture()

    session =
      Phantom.Test.build_session(Router, assigns: %{scope: scope})

    %{
      session: session,
      scope: scope,
      other_scope: other_scope
    }
  end

  describe "applications" do
    test "create returns the application with the default status", %{
      session: session
    } do
      result =
        call_tool(session, :applications_create, %{
          "position" => "Senior Engineer",
          "company_name" => "Acme Corp",
          "recruiter_name" => "Jane",
          "description" => "Build things",
          "job_posting_url" => "https://example.com/jobs/1",
          "tag_ids" => [],
          "new_tag_names" => ["remote", "elixir"]
        })

      assert not failed?(result)

      application = result.structuredContent["application"]
      assert application["position"] == "Senior Engineer"
      assert application["company_name"] == "Acme Corp"
      assert application["recruiter_name"] == "Jane"
      assert application["status"]["slug"] == "interested"
      assert application["tags"] |> Enum.map(& &1["name"]) |> Enum.sort() == ["elixir", "remote"]

      # history appended
      history =
        call_tool(session, :applications_status_history, %{"id" => application["id"]})

      assert history.structuredContent["history"] |> length() == 1
    end

    test "list, get, update, change status, and delete", %{session: session, scope: scope} do
      app = JobApplicationsFixtures.application_fixture(scope)
      tag = TagsFixtures.tag_fixture(scope, %{name: "remote"})

      # link tag through update
      result =
        call_tool(session, :applications_update, %{
          "id" => app.id,
          "position" => "Staff Engineer",
          "tag_ids" => [tag.id]
        })

      assert not failed?(result)
      updated = result.structuredContent["application"]
      assert updated["position"] == "Staff Engineer"
      assert Enum.map(updated["tags"], & &1["id"]) == [tag.id]

      # get
      got = call_tool(session, :applications_get, %{"id" => app.id})
      assert got.structuredContent["application"]["position"] == "Staff Engineer"

      # change status
      statuses = call_tool(session, :statuses_list, %{})

      interviewing =
        Enum.find(statuses.structuredContent["statuses"], &(&1["slug"] == "interview"))

      assert interviewing

      changed =
        call_tool(session, :applications_change_status, %{
          "id" => app.id,
          "status" => "interview",
          "notes" => "Great call"
        })

      assert not failed?(changed)
      assert changed.structuredContent["application"]["status"]["slug"] == "interview"

      # history now has 2
      history = call_tool(session, :applications_status_history, %{"id" => app.id})
      assert length(history.structuredContent["history"]) == 2

      # list
      listed = call_tool(session, :applications_list, %{})
      assert Enum.any?(listed.structuredContent["applications"], &(&1["id"] == app.id))

      # delete
      deleted = call_tool(session, :applications_delete, %{"id" => app.id})
      assert deleted.structuredContent["deleted"] == true

      # get now not found
      missing = call_tool(session, :applications_get, %{"id" => app.id})
      assert failed?(missing)
    end

    test "omitting tag_ids preserves linked tags", %{session: session, scope: scope} do
      app = JobApplicationsFixtures.application_fixture(scope)
      tag = TagsFixtures.tag_fixture(scope, %{name: "remote"})

      call_tool(session, :applications_update, %{"id" => app.id, "tag_ids" => [tag.id]})

      result =
        call_tool(session, :applications_update, %{"id" => app.id, "position" => "Renamed"})

      assert not failed?(result)
      assert Enum.map(result.structuredContent["application"]["tags"], & &1["id"]) == [tag.id]
    end

    test "tag_ids [] clears linked tags", %{session: session, scope: scope} do
      app = JobApplicationsFixtures.application_fixture(scope)
      tag = TagsFixtures.tag_fixture(scope, %{name: "remote"})

      call_tool(session, :applications_update, %{"id" => app.id, "tag_ids" => [tag.id]})

      result = call_tool(session, :applications_update, %{"id" => app.id, "tag_ids" => []})
      assert not failed?(result)
      assert result.structuredContent["application"]["tags"] == []
    end

    test "rejects another user's tag ids", %{
      session: session,
      scope: scope,
      other_scope: other_scope
    } do
      app = JobApplicationsFixtures.application_fixture(scope)
      other_tag = TagsFixtures.tag_fixture(other_scope, %{name: "private"})

      result =
        call_tool(session, :applications_update, %{
          "id" => app.id,
          "tag_ids" => [other_tag.id]
        })

      assert failed?(result)
    end

    test "rejects an invalid status slug", %{session: session, scope: scope} do
      app = JobApplicationsFixtures.application_fixture(scope)

      result =
        call_tool(session, :applications_change_status, %{
          "id" => app.id,
          "status" => "nope"
        })

      assert failed?(result)
    end

    test "rejects a same-status change", %{session: session, scope: scope} do
      app = JobApplicationsFixtures.application_fixture(scope)

      result =
        call_tool(session, :applications_change_status, %{
          "id" => app.id,
          "status" => "interested"
        })

      assert failed?(result)
    end

    test "returns not found for another user's application", %{
      session: session,
      other_scope: other_scope
    } do
      other_app = JobApplicationsFixtures.application_fixture(other_scope)

      result = call_tool(session, :applications_get, %{"id" => other_app.id})
      assert failed?(result)
    end

    test "validates required fields", %{session: session} do
      result = call_tool(session, :applications_create, %{})

      assert failed?(result)
    end
  end

  describe "resumes" do
    test "create, get, update, list, delete", %{session: session, scope: scope} do
      result =
        call_tool(session, :resumes_create, %{
          "title" => "Backend resume",
          "body" => "Experience",
          "email" => "candidate@example.com",
          "new_tag_names" => ["remote"]
        })

      assert not failed?(result)
      resume = result.structuredContent["resume"]
      assert resume["title"] == "Backend resume"
      assert resume["email"] == "candidate@example.com"
      assert resume["tags"] |> Enum.map(& &1["name"]) == ["remote"]

      # email prefilled from account when omitted
      prefilled =
        call_tool(session, :resumes_create, %{
          "title" => "Second",
          "body" => "Body"
        })

      assert prefilled.structuredContent["resume"]["email"] == scope.user.email

      # get
      got = call_tool(session, :resumes_get, %{"id" => resume["id"]})
      assert got.structuredContent["resume"]["body"] == "Experience"

      # update with omitted tags preserves
      updated =
        call_tool(session, :resumes_update, %{
          "id" => resume["id"],
          "title" => "Backend resume v2",
          "tag_ids" => []
        })

      assert not failed?(updated)
      assert updated.structuredContent["resume"]["title"] == "Backend resume v2"
      assert updated.structuredContent["resume"]["tags"] == []

      # list
      listed = call_tool(session, :resumes_list, %{})
      assert Enum.any?(listed.structuredContent["resumes"], &(&1["id"] == resume["id"]))

      # delete
      deleted = call_tool(session, :resumes_delete, %{"id" => resume["id"]})
      assert deleted.structuredContent["deleted"] == true

      missing = call_tool(session, :resumes_get, %{"id" => resume["id"]})
      assert failed?(missing)
    end

    test "returns not found for another user's resume", %{
      session: session,
      other_scope: other_scope
    } do
      other_resume = ResumesFixtures.resume_fixture(other_scope)

      result = call_tool(session, :resumes_get, %{"id" => other_resume.id})
      assert failed?(result)
    end

    test "validates required fields", %{session: session} do
      result = call_tool(session, :resumes_create, %{})
      assert failed?(result)
    end
  end

  describe "reference data" do
    test "tags_list and statuses_list", %{session: session, scope: scope} do
      tag = TagsFixtures.tag_fixture(scope, %{name: "remote"})

      tags = call_tool(session, :tags_list, %{})
      assert Enum.any?(tags.structuredContent["tags"], &(&1["id"] == tag.id))

      statuses = call_tool(session, :statuses_list, %{})
      slugs = Enum.map(statuses.structuredContent["statuses"], & &1["slug"])
      assert "interested" in slugs
      assert "applied" in slugs
    end
  end

  def failed?({:jsonrpc_error, _}), do: true
  def failed?(%{isError: true}), do: true
  def failed?(%{error: _}), do: true
  def failed?(_), do: false

  # (uses Phantom.Test.call_tool/3 directly)
end
