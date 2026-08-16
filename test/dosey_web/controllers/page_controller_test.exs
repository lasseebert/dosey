defmodule DoseyWeb.PageControllerTest do
  use DoseyWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "Dosey"
    assert response =~ "Dosey er en medicindagbog til privat brug."
    assert response =~ "Den er ikke åben (endnu) for andre end mig :)"
    assert response =~ "Lasse Skindstad Ebert"
    assert response =~ "lasse@lasseebert.dk"
    assert response =~ "Log ind"
    assert response =~ ~s(href="/login")
    assert response =~ ~s(src="/images/dosey-logo.png")
    assert response =~ ~s(rel="icon")
    assert response =~ ~s(href="/favicon.ico")
  end
end
