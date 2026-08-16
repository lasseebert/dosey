defmodule DoseyWeb.UserSessionController do
  use DoseyWeb, :controller

  alias Dosey.Accounts
  alias DoseyWeb.UserAuth

  def new(conn, _params) do
    render(conn, :new, error_message: nil, email: "")
  end

  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case Accounts.authenticate_user_by_email_and_password(email, password) do
      {:ok, user} ->
        UserAuth.log_in_user(conn, user)

      :error ->
        render(conn, :new,
          error_message: "Forkert email eller adgangskode",
          email: email
        )
    end
  end

  def create(conn, _params) do
    render(conn, :new,
      error_message: "Forkert email eller adgangskode",
      email: ""
    )
  end

  def delete(conn, _params) do
    UserAuth.log_out_user(conn)
  end
end
