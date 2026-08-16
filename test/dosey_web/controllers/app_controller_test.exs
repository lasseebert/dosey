defmodule DoseyWeb.AppControllerTest do
  use DoseyWeb.ConnCase

  alias Dosey.Accounts
  alias Dosey.Accounts.UserRegistration

  describe "GET /app" do
    test "redirects unauthenticated users to the login page", %{conn: conn} do
      conn = get(conn, ~p"/app")

      assert redirected_to(conn) == ~p"/login"
    end

    test "renders the diary app page for authenticated users", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> init_test_session(user_id: user.id)
        |> get(~p"/app")

      response = html_response(conn, 200)

      assert response =~ "Dosey"
      assert response =~ "Dagbog"
      assert response =~ "Seneste syv dage"
      assert response =~ "Log ud"
    end
  end

  defp user_fixture do
    assert {:ok, user} =
             Accounts.register_user(
               UserRegistration.new(
                 email: "parent@example.com",
                 password: "correct horse battery staple"
               )
             )

    user
  end
end
