defmodule Mix.Tasks.Resumes.CreateTest do
  use TrackMyJobEx.DataCase, async: false

  import ExUnit.CaptureIO
  import TrackMyJobEx.AccountsFixtures

  alias Mix.Tasks.Resumes.Create, as: ResumesCreate
  alias TrackMyJobEx.Accounts.Scope
  alias TrackMyJobEx.Resumes

  describe "mix resumes.create" do
    test "creates a simple resume for an existing user" do
      user = user_fixture()

      output =
        capture_io(fn ->
          ResumesCreate.run([user.email])
        end)

      assert output =~ "Created resume \"Simple resume\" for #{user.email}"

      assert [resume] = Resumes.list_resumes(Scope.for_user(user))
      assert resume.title == "Simple resume"
      assert resume.email == user.email
      assert resume.body =~ "Summary"
      assert resume.tags == []
    end

    test "uses a custom title" do
      user = user_fixture()

      capture_io(fn ->
        ResumesCreate.run([user.email, "--title", "Backend Engineer"])
      end)

      assert [resume] = Resumes.list_resumes(Scope.for_user(user))
      assert resume.title == "Backend Engineer"
    end

    test "creates the resume only for the given user" do
      user = user_fixture()
      other_user = user_fixture()

      capture_io(fn -> ResumesCreate.run([user.email]) end)

      assert [_resume] = Resumes.list_resumes(Scope.for_user(user))
      assert Resumes.list_resumes(Scope.for_user(other_user)) == []
    end

    test "fails clearly when the user does not exist" do
      email = "missing-#{System.unique_integer([:positive])}@example.com"

      capture_io(fn ->
        assert_raise Mix.Error, ~r/No user found with email #{Regex.escape(email)}/, fn ->
          ResumesCreate.run([email])
        end
      end)
    end

    test "fails clearly when the email is missing" do
      capture_io(fn ->
        assert_raise Mix.Error, ~r/Usage: mix resumes.create EMAIL/, fn ->
          ResumesCreate.run([])
        end
      end)
    end

    test "fails clearly on a blank title" do
      user = user_fixture()

      capture_io(fn ->
        assert_raise Mix.Error, ~r/title can't be blank/, fn ->
          ResumesCreate.run([user.email, "--title", "   "])
        end
      end)

      assert Resumes.list_resumes(Scope.for_user(user)) == []
    end

    test "fails clearly on unknown options" do
      capture_io(fn ->
        assert_raise Mix.Error, ~r/Invalid options/, fn ->
          ResumesCreate.run(["alice@example.com", "--unknown", "value"])
        end
      end)
    end
  end
end
