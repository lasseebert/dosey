defmodule DoseyWeb.UserSessionControllerTest do
  use DoseyWeb.ConnCase

  alias Dosey.Accounts
  alias Dosey.Accounts.UserRegistration

  @valid_password "correct horse battery staple"

  describe "GET /login" do
    test "renders the login form", %{conn: conn} do
      conn = get(conn, ~p"/login")
      response = html_response(conn, 200)

      assert response =~ "Log ind"
      assert response =~ "Email"
      assert response =~ "Adgangskode"
      assert response =~ ~s(action="/login")
    end
  end

  describe "POST /login" do
    test "logs the user in and redirects to the private app", %{conn: conn} do
      user = user_fixture()

      conn =
        post(conn, ~p"/login", %{
          "user" => %{"email" => user.email, "password" => @valid_password}
        })

      assert get_session(conn, :user_id) == user.id
      assert redirected_to(conn) == ~p"/app"
    end

    test "shows a Danish error for invalid credentials", %{conn: conn} do
      conn =
        post(conn, ~p"/login", %{
          "user" => %{"email" => "wrong@example.com", "password" => "wrong password"}
        })

      response = html_response(conn, 200)

      assert response =~ "Forkert email eller adgangskode"
      refute get_session(conn, :user_id)
    end
  end

  describe "POST /logout" do
    test "clears the user session and redirects to the frontpage", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> init_test_session(user_id: user.id)
        |> post(~p"/logout")

      refute get_session(conn, :user_id)
      assert redirected_to(conn) == ~p"/"
    end
  end

  defp user_fixture do
    assert {:ok, user} =
             Accounts.register_user(
               UserRegistration.new(
                 email: "parent@example.com",
                 password: @valid_password
               )
             )

    user
  end
end
