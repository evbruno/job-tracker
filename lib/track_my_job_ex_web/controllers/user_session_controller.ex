defmodule TrackMyJobExWeb.UserSessionController do
  use TrackMyJobExWeb, :controller

  alias TrackMyJobEx.Accounts
  alias TrackMyJobExWeb.UserAuth

  def create(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      cond do
        user.temporary_password and user_params["new_password"] ->
          update_temporary_password(conn, email, password, user_params)

        user.temporary_password ->
          conn
          |> put_flash(:email, String.slice(email, 0, 160))
          |> redirect(to: ~p"/users/log-in?change_password=true")

        true ->
          conn
          |> put_flash(:info, "Welcome back!")
          |> UserAuth.log_in_user(user, user_params)
      end
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log-in")
    end
  end

  defp update_temporary_password(conn, email, current_password, params) do
    if params["new_password"] != params["new_password_confirmation"] do
      conn
      |> put_flash(:email, String.slice(email, 0, 160))
      |> put_flash(:error, "New passwords do not match.")
      |> redirect(to: ~p"/users/log-in?change_password=true")
    else
      case Accounts.change_temporary_password(email, current_password, params["new_password"]) do
        {:ok, user} ->
          conn
          |> put_flash(:info, "Password updated. Welcome back!")
          |> UserAuth.log_in_user(user, params)

        {:error, %Ecto.Changeset{} = changeset} ->
          conn
          |> put_flash(:email, String.slice(email, 0, 160))
          |> put_flash(:error, password_errors(changeset))
          |> redirect(to: ~p"/users/log-in?change_password=true")

        {:error, :invalid_current_password} ->
          conn
          |> put_flash(:error, "Invalid email or password")
          |> put_flash(:email, String.slice(email, 0, 160))
          |> redirect(to: ~p"/users/log-in")
      end
    end
  end

  defp password_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join(", ", fn {field, messages} -> "#{field} #{Enum.join(messages, ", ")}" end)
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
