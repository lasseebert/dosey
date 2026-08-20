defmodule DoseyWeb.AppLive do
  use DoseyWeb, :live_view

  alias Dosey.Accounts
  alias Dosey.Diary
  alias Dosey.Diary.Day
  alias Dosey.Diary.Event

  @day_count 7

  @impl true
  def mount(_params, %{"user_id" => user_id}, socket) do
    case Accounts.get_user(user_id) do
      nil -> {:ok, redirect(socket, to: ~p"/login")}
      _user -> mount_authenticated(socket)
    end
  end

  def mount(_params, _session, socket), do: {:ok, redirect(socket, to: ~p"/login")}

  defp mount_authenticated(socket) do
    today = today()
    yesterday = Date.add(today, -1)

    with {:ok, _today} <- Diary.get_or_create_day(today),
         {:ok, _yesterday} <- Diary.get_or_create_day(yesterday) do
      {:ok,
       socket
       |> assign(:today, today)
       |> assign(:yesterday, yesterday)
       |> assign(:saved_at, nil)
       |> assign(:saved_status_ref, nil)
       |> assign(:error_message, nil)
       |> load_days()}
    else
      {:error, _changeset} ->
        {:ok,
         socket
         |> assign(:today, today)
         |> assign(:yesterday, yesterday)
         |> assign(:days, [])
         |> assign(:saved_at, nil)
         |> assign(:saved_status_ref, nil)
         |> assign(:error_message, "Dagen kunne ikke oprettes.")}
    end
  end

  @impl true
  def handle_info(:clear_saved_status, socket) do
    {:noreply, clear_saved_status(socket)}
  end

  def handle_info({:clear_saved_status, ref}, socket) do
    if socket.assigns.saved_status_ref == ref do
      {:noreply, clear_saved_status(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update-day", %{"date" => date_string, "day" => attrs}, socket) do
    date = Date.from_iso8601!(date_string)

    with {:ok, %Day{} = day} <- Diary.get_or_create_day(date),
         {:ok, attrs} <- normalize_day_attrs(attrs),
         {:ok, _day} <- Diary.update_day(day, attrs) do
      {:noreply, socket |> mark_saved() |> load_days()}
    else
      _error -> {:noreply, assign(socket, :error_message, "Dagen kunne ikke gemmes.")}
    end
  end

  def handle_event(
        "update-day-field",
        %{"date" => date_string, "field" => field, "value" => value},
        socket
      ) do
    date = Date.from_iso8601!(date_string)

    with {:ok, %Day{} = day} <- Diary.get_or_create_day(date),
         {:ok, attrs} <- normalize_day_attrs(%{field => value}),
         {:ok, _day} <- Diary.update_day(day, attrs) do
      {:noreply, socket |> mark_saved() |> load_days()}
    else
      _error -> {:noreply, assign(socket, :error_message, "Dagen kunne ikke gemmes.")}
    end
  end

  def handle_event(
        "set-day-time-now",
        %{"date" => date_string, "field" => field},
        socket
      ) do
    date = Date.from_iso8601!(date_string)

    with true <- field in ["wake_time", "medicine_time", "sleep_time"],
         {:ok, %Day{} = day} <- Diary.get_or_create_day(date),
         {:ok, _day} <- Diary.update_day(day, %{field => current_copenhagen_time()}) do
      {:noreply, socket |> mark_saved() |> load_days()}
    else
      _error -> {:noreply, assign(socket, :error_message, "Dagen kunne ikke gemmes.")}
    end
  end

  def handle_event("add-event", %{"date" => date_string, "event" => attrs}, socket) do
    date = Date.from_iso8601!(date_string)

    with {:ok, %Day{} = day} <- Diary.get_or_create_day(date),
         {:ok, attrs} <- normalize_event_attrs(attrs),
         {:ok, _event} <- Diary.add_event(day, attrs) do
      {:noreply, socket |> mark_saved() |> load_days()}
    else
      _error -> {:noreply, assign(socket, :error_message, "Hændelsen kunne ikke gemmes.")}
    end
  end

  def handle_event(
        "quick-add-event",
        %{"date" => date_string, "event-type" => event_type},
        socket
      ) do
    date = Date.from_iso8601!(date_string)

    with true <- event_type in Enum.map(quick_add_event_types(), &Atom.to_string/1),
         {:ok, %Day{} = day} <- Diary.get_or_create_day(date),
         {:ok, _event} <-
           Diary.add_event(day, %{
             event_type: String.to_existing_atom(event_type),
             started_at_time: current_copenhagen_time()
           }) do
      {:noreply, socket |> mark_saved() |> load_days()}
    else
      _error -> {:noreply, assign(socket, :error_message, "Hændelsen kunne ikke gemmes.")}
    end
  end

  def handle_event(
        "update-event-field",
        %{"id" => id, "field" => field, "value" => value},
        socket
      ) do
    event = find_event(socket.assigns.days, id)

    with %Event{} = event <- event,
         {:ok, attrs} <- normalize_event_attrs(%{field => value}),
         {:ok, _event} <- Diary.update_event(event, attrs) do
      {:noreply, socket |> mark_saved() |> load_days()}
    else
      _error -> {:noreply, assign(socket, :error_message, "Hændelsen kunne ikke gemmes.")}
    end
  end

  def handle_event("update-event", %{"event_id" => id, "event" => attrs}, socket) do
    event = find_event(socket.assigns.days, id)

    with %Event{} = event <- event,
         {:ok, attrs} <- normalize_event_attrs(attrs),
         {:ok, _event} <- Diary.update_event(event, attrs) do
      {:noreply, socket |> mark_saved() |> load_days()}
    else
      _error -> {:noreply, assign(socket, :error_message, "Hændelsen kunne ikke gemmes.")}
    end
  end

  def handle_event("delete-event", %{"id" => id}, socket) do
    event = find_event(socket.assigns.days, id)

    with %Event{} = event <- event,
         {:ok, _event} <- Diary.delete_event(event) do
      {:noreply, socket |> mark_saved() |> load_days()}
    else
      _error -> {:noreply, assign(socket, :error_message, "Hændelsen kunne ikke slettes.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />

    <main class="min-h-screen bg-[#f7faf8] text-[#172526]">
      <p
        :if={@saved_at}
        id="save-status"
        class="fixed left-4 right-4 z-50 mx-auto max-w-sm rounded-md bg-[#dff3e9] px-4 py-3 text-center text-sm font-medium text-[#17624f] shadow-lg"
        style="top: calc(env(safe-area-inset-top, 0px) + 1rem);"
      >
        Gemt {@saved_at}
      </p>

      <section class="mx-auto flex min-h-screen w-full max-w-5xl flex-col px-4 py-4 sm:px-8 lg:px-12">
        <header class="flex items-center justify-between gap-4">
          <a href={~p"/app"} class="flex items-center gap-3">
            <img src={~p"/images/dosey-logo.png"} alt="Dosey logo" class="h-11 w-11 rounded-lg" />
            <span class="text-xl font-semibold">Dosey</span>
          </a>

          <.link
            href={~p"/logout"}
            method="delete"
            class="rounded-lg border border-[#cbd8d2] bg-white px-4 py-2 text-sm font-medium text-[#344845] hover:border-[#92c7bc] hover:text-[#0b6f6b]"
          >
            Log ud
          </.link>
        </header>

        <div class="mt-7">
          <div>
            <h1 class="text-3xl font-semibold tracking-normal text-[#102021]">Dagbog</h1>
            <p class="mt-1 text-sm text-[#53635f]">Seneste syv dage</p>
          </div>
        </div>

        <p :if={@error_message} class="mt-4 rounded-md bg-[#ffe8e2] px-3 py-2 text-sm text-[#8a2d1b]">
          {@error_message}
        </p>

        <div class="mt-5 flex flex-col gap-4">
          <article
            :for={day <- @days}
            id={"day-#{Date.to_iso8601(day.date)}"}
            data-day-date={Date.to_iso8601(day.date)}
            class="rounded-lg border border-[#d7e1dd] bg-white p-4 shadow-sm"
          >
            <div class="flex items-start justify-between gap-3">
              <div>
                <h2 class="text-lg font-semibold text-[#172526]">
                  {day_title(day.date, @today, @yesterday)}
                </h2>
                <p class="text-sm text-[#60706c]">{format_date(day.date)}</p>
              </div>
            </div>

            <.editable_day day={day} />
          </article>
        </div>
      </section>
    </main>
    """
  end

  defp editable_day(assigns) do
    ~H"""
    <form
      id={"day-#{Date.to_iso8601(@day.date)}-form"}
      class="mt-4 grid grid-cols-3 gap-3 text-sm"
    >
      <input type="hidden" name="date" value={Date.to_iso8601(@day.date)} />
      <.day_time_editor
        label="Vågnede"
        name="day[wake_time]"
        date={@day.date}
        field="wake_time"
        value={@day.wake_time}
        phx_blur="update-day-field"
        phx_value_date={Date.to_iso8601(@day.date)}
        phx_value_field="wake_time"
      />
      <.day_time_editor
        label="Medicin"
        name="day[medicine_time]"
        date={@day.date}
        field="medicine_time"
        value={@day.medicine_time}
        phx_blur="update-day-field"
        phx_value_date={Date.to_iso8601(@day.date)}
        phx_value_field="medicine_time"
      />
      <.day_time_editor
        label="Sov"
        name="day[sleep_time]"
        date={@day.date}
        field="sleep_time"
        value={@day.sleep_time}
        phx_blur="update-day-field"
        phx_value_date={Date.to_iso8601(@day.date)}
        phx_value_field="sleep_time"
      />
    </form>

    <section class="mt-5">
      <h3 class="text-sm font-semibold text-[#344845]">Hændelser</h3>
      <div
        id={"event-new-#{Date.to_iso8601(@day.date)}-actions"}
        class="relative mt-2 flex flex-wrap gap-2"
      >
        <button
          :for={type <- quick_add_event_types()}
          id={"event-new-#{Date.to_iso8601(@day.date)}-#{type}-quick-add"}
          type="button"
          phx-click="quick-add-event"
          phx-value-date={Date.to_iso8601(@day.date)}
          phx-value-event-type={type}
          class="rounded-md bg-[#f5f8f6] px-3 py-2 text-sm font-medium text-[#0b6f6b] hover:bg-[#eef3f1]"
        >
          {event_type_label(type)}
        </button>
        <details
          id={"event-new-#{Date.to_iso8601(@day.date)}-popup"}
          data-event-popup
        >
          <summary
            id={"event-new-#{Date.to_iso8601(@day.date)}-other-summary"}
            class="cursor-pointer list-none rounded-md bg-[#f5f8f6] px-3 py-2 text-sm font-medium text-[#0b6f6b] marker:hidden hover:bg-[#eef3f1]"
          >
            Andet
          </summary>

          <form
            id={"event-new-#{Date.to_iso8601(@day.date)}-form"}
            class="absolute left-0 right-0 top-full z-20 mt-2 grid grid-cols-1 gap-2 rounded-md border border-[#cbd8d2] bg-white p-3 shadow-lg sm:grid-cols-[minmax(0,1fr)_minmax(0,2fr)_auto_auto_auto]"
            phx-submit="add-event"
          >
            <input type="hidden" name="date" value={Date.to_iso8601(@day.date)} />
            <.event_type_select
              name="event[event_type]"
              value={nil}
              event_types={manual_event_types()}
              data_event_input
            />
            <input
              name="event[text]"
              type="text"
              placeholder="Hvad skete der?"
              data-event-input
              class="rounded-md border border-[#cbd8d2] px-3 py-2 text-sm"
            />
            <input
              name="event[started_at_time]"
              type="text"
              inputmode="numeric"
              placeholder="tt:mm"
              value={format_time_input(current_copenhagen_time())}
              data-time-input
              data-event-input
              class="rounded-md border border-[#cbd8d2] px-3 py-2 text-sm"
            />
            <input
              name="event[ended_at_time]"
              type="text"
              inputmode="numeric"
              placeholder="tt:mm"
              data-time-input
              data-event-input
              class="rounded-md border border-[#cbd8d2] px-3 py-2 text-sm"
            />
            <button
              type="submit"
              class="rounded-md bg-[#0b6f6b] px-3 py-2 text-sm font-semibold text-white"
            >
              Tilføj
            </button>
          </form>
        </details>
      </div>
      <div class="mt-2 flex flex-col gap-2">
        <.event_form :for={event <- @day.events} event={event} />
      </div>
    </section>
    """
  end

  defp event_form(assigns) do
    ~H"""
    <details id={"event-#{@event.id}-popup"} class="group relative" data-event-popup>
      <summary
        id={"event-#{@event.id}-summary"}
        class="cursor-pointer list-none rounded-md bg-[#f5f8f6] px-3 py-2 text-sm marker:hidden hover:bg-[#eef3f1]"
      >
        <span class="font-medium">{event_type_label(@event.event_type)}</span>
        <span class="text-[#60706c]">{event_range(@event)}</span>
        <p :if={@event.text} class="mt-1">{@event.text}</p>
      </summary>

      <form
        id={"event-#{@event.id}-form"}
        class="absolute left-0 top-full z-20 mt-2 grid w-full min-w-72 grid-cols-1 gap-2 rounded-md border border-[#cbd8d2] bg-white p-3 shadow-lg sm:grid-cols-[minmax(0,1fr)_minmax(0,2fr)_auto_auto_auto]"
        phx-change="update-event"
      >
        <input type="hidden" name="event_id" value={@event.id} />
        <.event_type_select
          name="event[event_type]"
          value={@event.event_type}
          data_event_input
        />
        <input
          name="event[text]"
          type="text"
          value={@event.text}
          data-event-input
          phx-blur="update-event-field"
          phx-value-id={@event.id}
          phx-value-field="text"
          class="rounded-md border border-[#cbd8d2] px-3 py-2 text-sm"
        />
        <input
          name="event[started_at_time]"
          type="text"
          inputmode="numeric"
          placeholder="tt:mm"
          value={format_time_input(@event.started_at_time)}
          data-time-input
          data-event-input
          phx-blur="update-event-field"
          phx-value-id={@event.id}
          phx-value-field="started_at_time"
          class="rounded-md border border-[#cbd8d2] px-3 py-2 text-sm"
        />
        <input
          name="event[ended_at_time]"
          type="text"
          inputmode="numeric"
          placeholder="tt:mm"
          value={format_time_input(@event.ended_at_time)}
          data-time-input
          data-event-input
          phx-blur="update-event-field"
          phx-value-id={@event.id}
          phx-value-field="ended_at_time"
          class="rounded-md border border-[#cbd8d2] px-3 py-2 text-sm"
        />
        <button
          id={"event-#{@event.id}-delete"}
          type="button"
          aria-label="Slet hændelse"
          phx-click="delete-event"
          phx-value-id={@event.id}
          data-confirm="Er du sikker på, at du vil slette hændelsen?"
          class="inline-flex size-10 items-center justify-center rounded-md border border-[#cbd8d2] bg-white text-[#8a2d1b] hover:bg-[#fff3ef]"
        >
          <.icon name="hero-trash" class="size-5" />
        </button>
      </form>
    </details>
    """
  end

  defp day_time_editor(assigns) do
    assigns =
      assigns
      |> assign(:date_string, Date.to_iso8601(assigns.date))
      |> assign(:input_id, "day-#{Date.to_iso8601(assigns.date)}-#{assigns.field}-input")
      |> assign(:trigger_id, "day-#{Date.to_iso8601(assigns.date)}-#{assigns.field}-trigger")
      |> assign(:set_now_id, "day-#{Date.to_iso8601(assigns.date)}-#{assigns.field}-set-now")
      |> assign(:popup_position_class, day_time_popup_position_class(assigns.field))

    ~H"""
    <div class="text-sm" data-day-time-editor={@field}>
      <span class="mb-1 block font-medium text-[#344845]">{@label}</span>
      <details :if={@value} class="group relative" data-day-time-popup>
        <summary
          id={@trigger_id}
          class="block cursor-pointer list-none rounded-md bg-[#f5f8f6] px-3 py-2 font-medium text-[#172526] marker:hidden hover:bg-[#eef3f1]"
        >
          {format_time(@value)}
        </summary>
        <div class={[
          "absolute top-full z-20 mt-2 w-40 rounded-md border border-[#cbd8d2] bg-white p-3 shadow-lg",
          @popup_position_class
        ]}>
          <label for={@input_id} class="sr-only">{@label}</label>
          <input
            id={@input_id}
            name={@name}
            type="text"
            inputmode="numeric"
            value={format_time_input(@value)}
            data-time-input
            phx-blur={@phx_blur}
            phx-value-date={@phx_value_date}
            phx-value-field={@phx_value_field}
            class="w-full rounded-md border border-[#cbd8d2] px-3 py-2"
          />
        </div>
      </details>
      <button
        :if={!@value}
        id={@set_now_id}
        type="button"
        phx-click="set-day-time-now"
        phx-value-date={@date_string}
        phx-value-field={@field}
        class="w-full rounded-md bg-[#f5f8f6] px-3 py-2 text-left font-medium text-[#0b6f6b] hover:bg-[#eef3f1]"
      >
        Sæt nu
      </button>
    </div>
    """
  end

  defp event_type_select(assigns) do
    assigns =
      assigns
      |> assign_new(:event_types, fn -> Event.event_types() end)
      |> assign_new(:phx_change, fn -> nil end)
      |> assign_new(:phx_value_id, fn -> nil end)
      |> assign_new(:phx_value_field, fn -> nil end)
      |> assign_new(:data_event_input, fn -> false end)

    ~H"""
    <select
      name={@name}
      phx-change={@phx_change}
      phx-value-id={@phx_value_id}
      phx-value-field={@phx_value_field}
      data-event-input={@data_event_input}
      class="rounded-md border border-[#cbd8d2] px-3 py-2 text-sm"
    >
      <option :for={type <- @event_types} value={type} selected={@value == type}>
        {event_type_label(type)}
      </option>
    </select>
    """
  end

  defp quick_add_event_types, do: [:wake_attempt, :put_to_bed]

  defp manual_event_types, do: Event.event_types() -- quick_add_event_types()

  defp day_time_popup_position_class("sleep_time"), do: "right-0"
  defp day_time_popup_position_class(_field), do: "left-0"

  defp load_days(socket) do
    today = socket.assigns.today
    existing_days = Map.new(Diary.list_days(today, @day_count), &{&1.date, &1})

    days =
      for offset <- 0..(@day_count - 1) do
        date = Date.add(today, -offset)
        Map.get(existing_days, date, empty_day(date))
      end

    assign(socket, :days, days)
  end

  defp empty_day(date) do
    %Day{date: date, events: []}
  end

  defp today do
    Application.get_env(:dosey, :today, &copenhagen_today/0).()
  end

  defp copenhagen_today do
    now = Application.get_env(:dosey, :now, fn -> DateTime.utc_now() end).()

    now
    |> DateTime.add(copenhagen_utc_offset_seconds(now), :second)
    |> DateTime.to_date()
  end

  defp current_copenhagen_time do
    now = Application.get_env(:dosey, :now, fn -> DateTime.utc_now() end).()

    now
    |> DateTime.add(copenhagen_utc_offset_seconds(now), :second)
    |> DateTime.to_time()
    |> Time.truncate(:second)
  end

  defp copenhagen_utc_offset_seconds(%DateTime{} = utc_datetime) do
    if copenhagen_summer_time?(utc_datetime), do: 2 * 60 * 60, else: 60 * 60
  end

  defp copenhagen_summer_time?(%DateTime{year: year} = utc_datetime) do
    starts_at = copenhagen_summer_time_start(year)
    ends_at = copenhagen_summer_time_end(year)

    DateTime.compare(utc_datetime, starts_at) in [:eq, :gt] and
      DateTime.compare(utc_datetime, ends_at) == :lt
  end

  defp copenhagen_summer_time_start(year), do: last_sunday_at_utc_one(year, 3)
  defp copenhagen_summer_time_end(year), do: last_sunday_at_utc_one(year, 10)

  defp last_sunday_at_utc_one(year, month) do
    date = Date.end_of_month(Date.new!(year, month, 1))
    days_since_sunday = Date.day_of_week(date, :sunday) - 1
    date = Date.add(date, -days_since_sunday)

    DateTime.new!(date, ~T[01:00:00], "Etc/UTC")
  end

  defp mark_saved(socket) do
    ref = make_ref()
    Process.send_after(self(), {:clear_saved_status, ref}, 5_000)

    socket
    |> assign(:saved_at, Calendar.strftime(current_copenhagen_time(), "%H:%M:%S"))
    |> assign(:saved_status_ref, ref)
    |> assign(:error_message, nil)
  end

  defp clear_saved_status(socket) do
    socket
    |> assign(:saved_at, nil)
    |> assign(:saved_status_ref, nil)
  end

  defp find_event(days, event_id) do
    days
    |> Enum.flat_map(& &1.events)
    |> Enum.find(&(&1.id == event_id))
  end

  defp normalize_day_attrs(attrs) do
    normalize_time_attrs(attrs, ["wake_time", "medicine_time", "sleep_time"])
  end

  defp normalize_event_attrs(attrs) do
    normalize_time_attrs(attrs, ["started_at_time", "ended_at_time"])
  end

  defp normalize_time_attrs(attrs, time_keys) do
    attrs = normalize_empty_values(attrs)

    Enum.reduce_while(time_keys, {:ok, attrs}, fn key, {:ok, attrs} ->
      if Map.has_key?(attrs, key) do
        case parse_time(Map.get(attrs, key)) do
          {:ok, value} -> {:cont, {:ok, Map.put(attrs, key, value)}}
          :error -> {:halt, :error}
        end
      else
        {:cont, {:ok, attrs}}
      end
    end)
  end

  defp normalize_empty_values(attrs) do
    Map.new(attrs, fn
      {key, ""} -> {key, nil}
      pair -> pair
    end)
  end

  defp parse_time(nil), do: {:ok, nil}
  defp parse_time(%Time{} = time), do: {:ok, time}

  defp parse_time(value) when is_binary(value) do
    cond do
      Regex.match?(~r/^\d{1,2}$/, value) ->
        parse_time("#{value}:00")

      Regex.match?(~r/^\d{1,2}:\d{1,2}$/, value) ->
        [hour, minute] = String.split(value, ":")
        Time.new(parse_integer(hour), parse_integer(minute), 0)

      true ->
        :error
    end
  end

  defp parse_integer(value) do
    {integer, ""} = Integer.parse(value)
    integer
  end

  defp day_title(date, today, _yesterday) when date == today, do: "I dag"
  defp day_title(date, _today, yesterday) when date == yesterday, do: "I går"
  defp day_title(_date, _today, _yesterday), do: "Dag"

  defp format_date(date) do
    "#{date.day}. #{month_name(date.month)} #{date.year}"
  end

  defp month_name(1), do: "januar"
  defp month_name(2), do: "februar"
  defp month_name(3), do: "marts"
  defp month_name(4), do: "april"
  defp month_name(5), do: "maj"
  defp month_name(6), do: "juni"
  defp month_name(7), do: "juli"
  defp month_name(8), do: "august"
  defp month_name(9), do: "september"
  defp month_name(10), do: "oktober"
  defp month_name(11), do: "november"
  defp month_name(12), do: "december"

  defp format_time(%Time{} = time), do: Calendar.strftime(time, "%H:%M")

  defp format_time_input(nil), do: nil

  defp format_time_input(%Time{} = time) do
    "#{time.hour}:#{pad_minute(time.minute)}"
  end

  defp pad_minute(minute) when minute < 10, do: "0#{minute}"
  defp pad_minute(minute), do: Integer.to_string(minute)

  defp event_range(%Event{started_at_time: nil, ended_at_time: nil}), do: ""

  defp event_range(%Event{started_at_time: start_time, ended_at_time: nil}),
    do: format_time(start_time)

  defp event_range(%Event{started_at_time: nil, ended_at_time: end_time}) do
    "til #{format_time(end_time)}"
  end

  defp event_range(%Event{started_at_time: start_time, ended_at_time: end_time}) do
    "#{format_time(start_time)}-#{format_time(end_time)}"
  end

  defp event_type_label(:social), do: "Socialt"
  defp event_type_label(:meltdown), do: "Nedsmeltning"
  defp event_type_label(:meal), do: "Måltid"
  defp event_type_label(:school), do: "Skole"
  defp event_type_label(:activity), do: "Aktivitet"
  defp event_type_label(:wake_attempt), do: "Vækning"
  defp event_type_label(:put_to_bed), do: "Putning"
  defp event_type_label(:other), do: "Andet"
end
