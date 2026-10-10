defmodule DoseyWeb.DiaryExportControllerTest do
  use DoseyWeb.ConnCase, async: true

  alias Dosey.Accounts
  alias Dosey.Accounts.UserRegistration
  alias Dosey.Diary

  @valid_password "correct horse battery staple"

  describe "GET /export" do
    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/export")

      assert redirected_to(conn) == "/login"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Du skal logge ind for at se den side."
    end

    test "downloads the complete diary as readable Markdown", %{conn: conn} do
      assert {:ok, first_day} = Diary.get_or_create_day(~D[2026-08-12])

      assert {:ok, _first_day} =
               Diary.update_day(first_day, %{
                 wake_time: ~T[09:00:00],
                 medicine_time: ~T[09:05:00],
                 sleep_time: ~T[22:00:00]
               })

      assert {:ok, _trip} =
               Diary.add_event(first_day, %{
                 event_type: :trip,
                 text: "Udflugt til stranden",
                 started_at_time: ~T[11:00:00],
                 ended_at_time: ~T[13:00:00]
               })

      assert {:ok, _meal} =
               Diary.add_event(first_day, %{
                 event_type: :meal,
                 text: "Spiste en is",
                 started_at_time: ~T[14:07:00]
               })

      assert {:ok, second_day} = Diary.get_or_create_day(~D[2026-08-13])

      assert {:ok, _other} =
               Diary.add_event(second_day, %{
                 event_type: :other,
                 text: "En dag uden registrerede tidspunkter"
               })

      conn =
        conn
        |> log_in_user()
        |> get("/export")

      assert get_resp_header(conn, "content-type") == ["text/markdown; charset=utf-8"]

      assert get_resp_header(conn, "content-disposition") ==
               [~s(attachment; filename="dosey-dagbog.md")]

      assert response(conn, 200) == """
             ## 2026-08-12

             * Vågnede: 09:00
             * Medicin: 09:05
             * Tur — Udflugt til stranden: 11:00 - 13:00
             * Måltid — Spiste en is: 14:07
             * Sov: 22:00

             ## 2026-08-13

             * Andet — En dag uden registrerede tidspunkter
             """
    end
  end

  defp log_in_user(conn) do
    assert {:ok, user} =
             Accounts.register_user(
               UserRegistration.new(
                 email: "parent@example.com",
                 password: @valid_password
               )
             )

    init_test_session(conn, user_id: user.id)
  end
end
