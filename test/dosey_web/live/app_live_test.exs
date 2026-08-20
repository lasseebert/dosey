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

    test "renders editable day times as timestamp editors", %{conn: conn} do
      assert {:ok, today} = Diary.get_or_create_day(~D[2026-08-16])

      assert {:ok, _today} =
               Diary.update_day(today, %{
                 wake_time: ~T[07:20:00],
                 medicine_time: ~T[13:05:00],
                 sleep_time: ~T[20:15:00]
               })

      {:ok, view, _html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      html = render(element(view, "#day-2026-08-16-form"))

      assert html =~ ~s(data-day-time-editor="wake_time")
      assert html =~ ~s(id="day-2026-08-16-wake_time-trigger")

      assert html =~
               ~r/<(?:button|summary)[^>]*id="day-2026-08-16-wake_time-trigger"[^>]*>\s*07:20\s*<\/(?:button|summary)>/

      assert html =~ ~s(name="day[wake_time]")
      assert html =~ ~s(value="7:20")

      assert html =~ ~s(data-day-time-editor="medicine_time")

      assert html =~
               ~r/<(?:button|summary)[^>]*id="day-2026-08-16-medicine_time-trigger"[^>]*>\s*13:05\s*<\/(?:button|summary)>/

      assert html =~ ~s(data-day-time-editor="sleep_time")

      assert html =~
               ~r/<(?:button|summary)[^>]*id="day-2026-08-16-sleep_time-trigger"[^>]*>\s*20:15\s*<\/(?:button|summary)>/

      refute html =~ ~s(placeholder="tt:mm")
    end

    test "renders empty editable day times as a set-now action", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      html = render(element(view, "#day-2026-08-16-form"))

      assert html =~ ~s(id="day-2026-08-16-wake_time-set-now")
      assert html =~ ~s(phx-click="set-day-time-now")
      assert html =~ ~s(phx-value-date="2026-08-16")
      assert html =~ ~s(phx-value-field="wake_time")

      assert html =~
               ~r/<button[^>]*id="day-2026-08-16-wake_time-set-now"[^>]*>\s*Sæt nu\s*<\/button>/

      refute html =~ ~s(id="day-2026-08-16-wake_time-trigger")
    end

    test "renders editable day times in a three-column row like read-only days", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      html = render(element(view, "#day-2026-08-16-form"))

      assert html =~ ~s(class="mt-4 grid grid-cols-3 gap-3 text-sm")
      refute html =~ ~s(grid-cols-1)
    end

    test "renders quick-add buttons for events and keeps them out of the new event dropdown", %{
      conn: conn
    } do
      {:ok, view, _html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      html = render(element(view, "#day-2026-08-16"))

      assert html =~ ~s(id="event-new-2026-08-16-wake_attempt-quick-add")
      assert html =~ ~s(id="event-new-2026-08-16-put_to_bed-quick-add")
      assert html =~ ~s(id="event-new-2026-08-16-other-summary")
      assert html =~ ~s(phx-click="quick-add-event")
      assert html =~ ~s(phx-value-date="2026-08-16")
      assert html =~ ~s(phx-value-event-type="wake_attempt")
      assert html =~ ~s(phx-value-event-type="put_to_bed")

      assert html =~
               ~r/<summary[^>]*id="event-new-2026-08-16-other-summary"[^>]*>\s*Andet\s*<\/summary>/

      new_event_form = render(element(view, "#event-new-2026-08-16-form"))

      refute new_event_form =~ ~s(value="wake_attempt")
      refute new_event_form =~ ~s(value="put_to_bed")
      assert new_event_form =~ ~s(value="meal")
    end

    test "renders the new event form inside the other event popup", %{conn: conn} do
      Application.delete_env(:dosey, :today)
      Application.put_env(:dosey, :now, fn -> ~U[2026-08-16 05:45:00Z] end)

      {:ok, view, _html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      html = render(element(view, "#event-new-2026-08-16-popup"))

      assert html =~ ~s(data-event-popup)
      assert html =~ ~s(id="event-new-2026-08-16-other-summary")
      assert html =~ ~s(id="event-new-2026-08-16-form")
      assert html =~ ~s(phx-submit="add-event")
      assert html =~ ~s(name="event[text]")
      assert html =~ ~s(data-event-input)
      assert html =~ ~s(name="event[started_at_time]")
      assert html =~ ~s(value="7:45")
      assert html =~ ~s(name="event[ended_at_time]")
    end

    test "aligns the new event popup inside the viewport", %{conn: conn} do
      {:ok, view, _html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      action_row = render(element(view, "#event-new-2026-08-16-actions"))
      html = render(element(view, "#event-new-2026-08-16-form"))

      assert action_row =~ ~s(relative)
      assert html =~ ~s(left-0)
      assert html =~ ~s(right-0)
      refute html =~ ~S|w-[min(90vw,44rem)]|
    end

    test "quick-add creates an event with the current Copenhagen time", %{conn: conn} do
      Application.delete_env(:dosey, :today)
      Application.put_env(:dosey, :now, fn -> ~U[2026-08-16 05:45:00Z] end)

      {:ok, view, _html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      html =
        view
        |> element("#event-new-2026-08-16-wake_attempt-quick-add")
        |> render_click()

      assert html =~ "Vækning"
      assert html =~ "07:45"
      assert html =~ "Gemt"

      today = Diary.get_day(~D[2026-08-16])
      [event] = today.events
      assert event.event_type == :wake_attempt
      assert event.started_at_time == ~T[07:45:00]
      assert event.ended_at_time == nil
      assert event.text == nil
    end

    test "renders quick-added event types like other events when editable and read-only", %{
      conn: conn
    } do
      assert {:ok, yesterday} = Diary.get_or_create_day(~D[2026-08-15])

      assert {:ok, event} =
               Diary.add_event(yesterday, %{
                 event_type: :put_to_bed,
                 started_at_time: ~T[19:45:00]
               })

      assert {:ok, older_day} = Diary.create_day(~D[2026-08-14])

      assert {:ok, _older_event} =
               Diary.add_event(older_day, %{
                 event_type: :wake_attempt,
                 started_at_time: ~T[07:05:00]
               })

      {:ok, view, html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      editable_event = render(element(view, "#event-#{event.id}-form"))

      assert editable_event =~ ~s(name="event[event_type]")
      assert editable_event =~ ~s(value="put_to_bed")
      assert editable_event =~ ~s(name="event[text]")
      assert editable_event =~ ~s(name="event[started_at_time]")
      assert editable_event =~ ~s(name="event[ended_at_time]")
      assert editable_event =~ ~s(value="19:45")

      assert html =~ "Vækning"
      assert html =~ "07:05"
    end

    test "renders editable events as compact rows that open editor popups", %{conn: conn} do
      assert {:ok, yesterday} = Diary.get_or_create_day(~D[2026-08-15])

      assert {:ok, event} =
               Diary.add_event(yesterday, %{
                 event_type: :meal,
                 text: "Spiste havregrød",
                 started_at_time: ~T[08:00:00]
               })

      {:ok, view, _html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      html = render(element(view, "#event-#{event.id}-popup"))

      assert html =~ ~s(data-event-popup)
      assert html =~ ~s(id="event-#{event.id}-summary")
      assert html =~ "Måltid"
      assert html =~ "08:00"
      assert html =~ "Spiste havregrød"
      assert html =~ ~s(id="event-#{event.id}-form")
      assert html =~ ~s(phx-blur="update-event-field")
      assert html =~ ~s(name="event[text]")

      refute html =~ ~r/^<form[^>]*id="event-#{event.id}-form"/
    end

    test "renders editable event delete as a confirmed garbage icon button", %{conn: conn} do
      assert {:ok, yesterday} = Diary.get_or_create_day(~D[2026-08-15])
      assert {:ok, event} = Diary.add_event(yesterday, %{event_type: :meal})

      {:ok, view, _html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      html = render(element(view, "#event-#{event.id}-delete"))

      assert html =~ ~s(aria-label="Slet hændelse")
      assert html =~ ~s(data-confirm="Er du sikker på, at du vil slette hændelsen?")
      assert html =~ ~s(hero-trash)
      refute html =~ ~r/>\s*Slet\s*</
    end

    test "aligns the rightmost editable day time popup inside the viewport", %{conn: conn} do
      assert {:ok, today} = Diary.get_or_create_day(~D[2026-08-16])
      assert {:ok, _today} = Diary.update_day(today, %{sleep_time: ~T[20:15:00]})

      {:ok, view, _html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      html = render(element(view, ~s(#day-2026-08-16-form [data-day-time-editor="sleep_time"])))

      assert html =~ ~s(right-0)
      refute html =~ ~s(left-0 top-full)
    end

    test "sets an empty editable day time to the current Copenhagen time", %{conn: conn} do
      Application.delete_env(:dosey, :today)
      Application.put_env(:dosey, :now, fn -> ~U[2026-08-16 05:45:00Z] end)

      {:ok, view, _html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      html =
        view
        |> element("#day-2026-08-16-wake_time-set-now")
        |> render_click()

      assert html =~ "07:45"
      assert html =~ "Gemt"

      assert day = Diary.get_day(~D[2026-08-16])
      assert day.wake_time == ~T[07:45:00]
    end

    test "shows the save confirmation time in Copenhagen time", %{conn: conn} do
      Application.delete_env(:dosey, :today)
      Application.put_env(:dosey, :now, fn -> ~U[2026-08-16 05:45:00Z] end)

      {:ok, view, _html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      html =
        view
        |> element("#day-2026-08-16-wake_time-set-now")
        |> render_click()

      assert html =~ "Gemt 07:45:00"
      refute html =~ "Gemt 05:45:00"
    end

    test "updates today's quick summary times on blur and shows save confirmation", %{conn: conn} do
      {:ok, today} = Diary.get_or_create_day(~D[2026-08-16])

      assert {:ok, _today} =
               Diary.update_day(today, %{
                 wake_time: ~T[07:00:00],
                 medicine_time: ~T[07:30:00],
                 sleep_time: ~T[20:00:00]
               })

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
      Application.put_env(:dosey, :now, fn -> ~U[2026-08-16 05:20:00Z] end)

      {:ok, view, _html} =
        conn
        |> log_in_user()
        |> live(~p"/app")

      html =
        view
        |> element("#day-2026-08-16-wake_time-set-now")
        |> render_click()

      assert html =~ ~s(id="save-status")

      send(view.pid, :clear_saved_status)
      html = render(view)

      refute html =~ ~s(id="save-status")
    end

    test "accepts loose time inputs and normalizes them after saving", %{conn: conn} do
      {:ok, today} = Diary.get_or_create_day(~D[2026-08-16])

      assert {:ok, _today} =
               Diary.update_day(today, %{
                 wake_time: ~T[08:00:00],
                 medicine_time: ~T[08:30:00],
                 sleep_time: ~T[19:30:00]
               })

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
      {:ok, today} = Diary.get_or_create_day(~D[2026-08-16])
      assert {:ok, _today} = Diary.update_day(today, %{wake_time: ~T[08:00:00]})

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
