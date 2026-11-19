defmodule Mix.Tasks.Users.CreateTest do
  use TrackMyJobEx.DataCase, async: false

  import ExUnit.CaptureIO
  import TrackMyJobEx.AccountsFixtures

  alias Mix.Tasks.Users.Create, as: UsersCreate
  alias TrackMyJobEx.Accounts

  describe "mix users.create" do
    test "creates a user with a password" do
      email = "provisioned#{System.unique_integer()}@example.com"

      output =
        capture_io(fn ->
          UsersCreate.run([email, "--password", valid_user_password()])
        end)

      assert output =~ "Created user #{email}"
      assert user = Accounts.get_user_by_email(email)
      assert Accounts.get_user_by_email_and_password(email, valid_user_password())
      assert is_nil(user.password)
    end

    test "fails clearly on a duplicate email in any casing" do
      email = "duplicate#{System.unique_integer()}@example.com"
      _user = user_fixture(%{email: email})

      assert_raise Mix.Error, ~r/email has already been taken/, fn ->
        UsersCreate.run([
          String.upcase(email),
          "--password",
          valid_user_password()
        ])
      end
    end

    test "fails clearly on an invalid email" do
      assert_raise Mix.Error, ~r/email must have the @ sign and no spaces/, fn ->
        UsersCreate.run(["not an email", "--password", valid_user_password()])
      end
    end

    test "fails clearly on a short password" do
      assert_raise Mix.Error, ~r/password should be at least 12 character/, fn ->
        UsersCreate.run([
          "short#{System.unique_integer()}@example.com",
          "--password",
          "short"
        ])
      end
    end

    test "fails clearly when the email is missing" do
      assert_raise Mix.Error, ~r/Usage: mix users.create EMAIL/, fn ->
        UsersCreate.run(["--password", valid_user_password()])
      end
    end

    test "fails clearly on unknown options" do
      assert_raise Mix.Error, ~r/Invalid options/, fn ->
        UsersCreate.run(["a@example.com", "--unknown", "value"])
      end
    end
  end
end
