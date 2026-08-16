defmodule DoseyWeb.UserAuth do
  @moduledoc """
  Controller plugs for cookie-session authentication.
  """

  import Phoenix.Controller
  import Plug.Conn

  alias Dosey.Accounts

  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)
    assign(conn, :current_user, user_id && Accounts.get_user(user_id))
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "Du skal logge ind for at se den side.")
      |> redirect(to: "/login")
      |> halt()
    end
  end

  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: "/app")
      |> halt()
    else
      conn
    end
  end

  def log_in_user(conn, user) do
    conn
    |> renew_session()
    |> put_session(:user_id, user.id)
    |> redirect(to: "/app")
  end

  def log_out_user(conn) do
    conn
    |> renew_session()
    |> redirect(to: "/")
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
