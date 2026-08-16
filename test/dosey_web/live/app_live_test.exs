defmodule DoseyWeb.AppLiveTest do
  use DoseyWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Dosey.Accounts
  alias Dosey.Accounts.UserRegistration
  alias Dosey.Diary

  setup do
    original_today = Application.get_env(:dosey, :today)
    original_now = Application.get_env(:dosey, :now)
    Application.put_env(:dosey, :today, fn -> ~D[2026-08-16] end)

    on_exit(fn ->
      if original_today do
        Application.put_env(:dosey, :today, original_today)
      else
        Application.delete_env(:dosey, :today)
      end

      if original_now do
        Application.put_env(:dosey, :now, original_now)
      else
        Application.delete_env(:dosey, :now)
      end
    end)

    :ok
  end

  describe "GET /app" do
    test "redirects unauthenticated users to the login page", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/app")
    end

    test "auto-creates today and yesterday before rendering", %{conn: conn} do
      {:ok, _view, html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      assert html =~ "I dag"
      assert html =~ "I går"
      assert Diary.get_day(~D[2026-08-16])
      assert Diary.get_day(~D[2026-08-15])
    end

    test "uses the Copenhagen local date for today", %{conn: conn} do
      Application.delete_env(:dosey, :today)
      Application.put_env(:dosey, :now, fn -> ~U[2025-12-31 23:30:00Z] end)

      {:ok, _view, html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      assert html =~ "1. januar 2026"
      assert Diary.get_day(~D[2026-01-01])
      assert Diary.get_day(~D[2025-12-31])
    end

    test "shows seven latest calendar days in descending order", %{conn: conn} do
      {:ok, _view, html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      assert html =~ "16. august 2026"
      assert html =~ "15. august 2026"
      assert html =~ "10. august 2026"
      assert html =~ "data-day-date=\"2026-08-16\""
      assert html =~ "data-day-date=\"2026-08-10\""
    end

    test "allows editing today and yesterday but renders older days read-only", %{conn: conn} do
      {:ok, _view, html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      assert html =~ ~s(id="day-2026-08-16-form")
      assert html =~ ~s(id="day-2026-08-15-form")
      refute html =~ ~s(id="day-2026-08-14-form")
      assert html =~ "Kun læsning"
    end

    test "renders times with 24-hour formatting", %{conn: conn} do
      assert {:ok, older_day} = Diary.create_day(~D[2026-08-14])

      assert {:ok, _older_day} =
               Diary.update_day(older_day, %{
                 wake_time: ~T[07:20:00],
                 medicine_time: ~T[13:05:00],
                 sleep_time: ~T[20:15:00]
               })

      assert {:ok, _event} =
               Diary.add_event(older_day, %{
                 event_type: :put_to_bed,
                 started_at_time: ~T[19:45:00],
                 ended_at_time: ~T[20:15:00]
               })

      {:ok, _view, html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      assert html =~ "07:20"
      assert html =~ "13:05"
      assert html =~ "20:15"
      assert html =~ "19:45-20:15"
      refute html =~ ~s(type="time")
      refute html =~ ~S|pattern="[0-9]{1,2}(:[0-9]{1,2})?"|
    end

    test "updates today's quick summary times on blur and shows save confirmation", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      assert render(element(view, "#day-2026-08-16-form")) =~ ~s(phx-blur="update-day-field")
      refute render(element(view, "#day-2026-08-16-form")) =~ ~s(phx-change=)

      view
      |> element(~s(#day-2026-08-16-form input[name="day[wake_time]"]))
      |> render_blur(%{"value" => "07:20"})

      view
      |> element(~s(#day-2026-08-16-form input[name="day[medicine_time]"]))
      |> render_blur(%{"value" => "07:50"})

      html =
        view
        |> element(~s(#day-2026-08-16-form input[name="day[sleep_time]"]))
        |> render_blur(%{"value" => "20:15"})

      assert html =~ "Gemt"
      assert html =~ ~s(id="save-status")
      assert html =~ "fixed"
      assert html =~ "safe-area-inset-top"
      assert day = Diary.get_day(~D[2026-08-16])
      assert day.wake_time == ~T[07:20:00]
      assert day.medicine_time == ~T[07:50:00]
      assert day.sleep_time == ~T[20:15:00]
    end

    test "hides the save confirmation after five seconds", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      html =
        view
        |> element(~s(#day-2026-08-16-form input[name="day[wake_time]"]))
        |> render_blur(%{"value" => "7:20"})

      assert html =~ ~s(id="save-status")

      send(view.pid, :clear_saved_status)
      html = render(view)

      refute html =~ ~s(id="save-status")
    end

    test "accepts loose time inputs and normalizes them after saving", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      view
      |> element(~s(#day-2026-08-16-form input[name="day[wake_time]"]))
      |> render_blur(%{"value" => "9"})

      view
      |> element(~s(#day-2026-08-16-form input[name="day[medicine_time]"]))
      |> render_blur(%{"value" => "9:00"})

      html =
        view
        |> element(~s(#day-2026-08-16-form input[name="day[sleep_time]"]))
        |> render_blur(%{"value" => "20"})

      assert html =~ ~s(value="9:00")
      assert html =~ ~s(value="20:00")

      assert day = Diary.get_day(~D[2026-08-16])
      assert day.wake_time == ~T[09:00:00]
      assert day.medicine_time == ~T[09:00:00]
      assert day.sleep_time == ~T[20:00:00]
    end

    test "normalizes a day time input after it loses focus", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      html =
        view
        |> element(~s(#day-2026-08-16-form input[name="day[wake_time]"]))
        |> render_blur(%{"value" => "9"})

      assert html =~ ~s(name="day[wake_time]")
      assert html =~ ~s(value="9:00")

      assert day = Diary.get_day(~D[2026-08-16])
      assert day.wake_time == ~T[09:00:00]
    end

    test "saving one day time field does not clear other day time fields", %{conn: conn} do
      {:ok, day} = Diary.get_or_create_day(~D[2026-08-16])

      assert {:ok, _day} =
               Diary.update_day(day, %{
                 wake_time: ~T[09:00:00],
                 medicine_time: ~T[10:00:00]
               })

      {:ok, view, _html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      view
      |> element(~s(#day-2026-08-16-form input[name="day[medicine_time]"]))
      |> render_blur(%{"value" => "10:30"})

      assert day = Diary.get_day(~D[2026-08-16])
      assert day.wake_time == ~T[09:00:00]
      assert day.medicine_time == ~T[10:30:00]
    end

    test "adds, edits, and deletes events for yesterday", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      html =
        view
        |> form("#event-new-2026-08-15-form", %{
          "event" => %{
            "event_type" => "meal",
            "text" => "Spiste havregrød",
            "started_at_time" => "08:00",
            "ended_at_time" => ""
          }
        })
        |> render_submit()

      assert html =~ "Spiste havregrød"

      yesterday = Diary.get_day(~D[2026-08-15])
      [event] = yesterday.events
      assert render(element(view, "#event-#{event.id}-form")) =~ ~s(phx-blur="update-event-field")
      refute render(element(view, "#event-#{event.id}-form")) =~ ~r/<form[^>]+phx-change=/

      view
      |> element(~s(#event-#{event.id}-form input[name="event[text]"]))
      |> render_blur(%{"value" => "Spiste yoghurt"})

      html =
        view
        |> element(~s(#event-#{event.id}-form input[name="event[started_at_time]"]))
        |> render_blur(%{"value" => "08:10"})

      assert html =~ "Spiste yoghurt"

      assert render(element(view, "#event-#{event.id}-delete")) =~
               ~s(data-confirm="Er du sikker på, at du vil slette hændelsen?")

      html = render_click(element(view, "#event-#{event.id}-delete"))

      assert html =~ "Gemt"
      assert Diary.get_day(~D[2026-08-15]).events == []
    end

    test "accepts loose event time inputs and normalizes them after saving", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      html =
        view
        |> form("#event-new-2026-08-15-form", %{
          "event" => %{
            "event_type" => "meal",
            "text" => "Morgenmad",
            "started_at_time" => "9",
            "ended_at_time" => "9:30"
          }
        })
        |> render_submit()

      assert html =~ ~s(value="9:00")
      assert html =~ ~s(value="9:30")

      yesterday = Diary.get_day(~D[2026-08-15])
      [event] = yesterday.events
      assert event.started_at_time == ~T[09:00:00]
      assert event.ended_at_time == ~T[09:30:00]
    end

    test "normalizes an event time input after it loses focus", %{conn: conn} do
      assert {:ok, day} = Diary.get_or_create_day(~D[2026-08-15])
      assert {:ok, event} = Diary.add_event(day, %{event_type: :meal})

      {:ok, view, html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      assert html =~ "event-#{event.id}-form"

      html =
        view
        |> element(~s(#event-#{event.id}-form input[name="event[started_at_time]"]))
        |> render_blur(%{"value" => "9:30"})

      assert html =~ ~s(value="9:30")

      [updated_event] = Diary.get_day(~D[2026-08-15]).events
      assert updated_event.started_at_time == ~T[09:30:00]
    end
  end

  defp log_in_user(conn) do
    user = user_fixture()
    init_test_session(conn, user_id: user.id)
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
