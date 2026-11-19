defmodule TrackMyJobEx.AccountsTest do
  use TrackMyJobEx.DataCase

  alias TrackMyJobEx.Accounts

  import TrackMyJobEx.AccountsFixtures
  alias TrackMyJobEx.Accounts.{User, UserToken}

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end

    test "matches email case-insensitively" do
      user = user_fixture(%{email: "CaseTest@Example.com"})
      assert %User{id: id} = Accounts.get_user_by_email(String.upcase(user.email))
      assert id == user.id
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", valid_user_password())
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture()
      refute Accounts.get_user_by_email_and_password(user.email, "invalid password")
    end

    test "does not authenticate a user with another user's password" do
      first = user_fixture()
      second = user_fixture(%{password: "another valid password"})

      refute Accounts.get_user_by_email_and_password(second.email, valid_user_password())
      assert Accounts.get_user_by_email_and_password(first.email, valid_user_password())
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "create_user/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.create_user(%{})

      assert %{email: ["can't be blank"], password: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email when given" do
      {:error, changeset} = Accounts.create_user(valid_user_attributes(email: "not valid"))

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum values for email for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.create_user(valid_user_attributes(email: too_long))
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates password length" do
      {:error, changeset} = Accounts.create_user(valid_user_attributes(password: "too short"))

      assert %{password: ["should be at least 12 character(s)"]} = errors_on(changeset)
    end

    test "validates maximum password length for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.create_user(valid_user_attributes(password: too_long))

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = user_fixture()
      {:error, changeset} = Accounts.create_user(valid_user_attributes(email: email))
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the uppercased email too, to check that email case is ignored.
      {:error, changeset} =
        Accounts.create_user(valid_user_attributes(email: String.upcase(email)))

      assert "has already been taken" in errors_on(changeset).email
    end

    test "enforces case-insensitive uniqueness at the database level" do
      user = user_fixture(%{email: "database@example.com"})

      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%User{email: String.upcase(user.email), hashed_password: "hash"})
      end
    end

    test "creates users with a hashed password" do
      email = unique_user_email()
      {:ok, user} = Accounts.create_user(valid_user_attributes(email: email))

      assert user.email == email
      assert is_binary(user.hashed_password)
      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(email, valid_user_password())
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"
      assert user_token.authenticated_at != nil

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end

    test "duplicates the authenticated_at of given user in new token", %{user: user} do
      user = %{user | authenticated_at: DateTime.add(DateTime.utc_now(:second), -3600)}
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.authenticated_at == user.authenticated_at
      assert DateTime.compare(user_token.inserted_at, user.authenticated_at) == :gt
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert {session_user, token_inserted_at} = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
      assert session_user.authenticated_at != nil
      assert token_inserted_at != nil
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      dt = ~N[2020-01-01 00:00:00]
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: dt, authenticated_at: dt])
      refute Accounts.get_user_by_session_token(token)
    end

    test "does not return a different user for a token", %{user: user, token: token} do
      other_user = user_fixture()
      assert {session_user, _} = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
      refute session_user.id == other_user.id
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
