defmodule DoseyWeb.DiaryExportController do
  use DoseyWeb, :controller

  alias Dosey.Diary
  alias Dosey.Diary.Day
  alias Dosey.Diary.Event

  def show(conn, _params) do
    markdown =
      Diary.list_all_days()
      |> Enum.map_join("\n\n", &format_day/1)
      |> Kernel.<>("\n")

    conn
    |> put_resp_content_type("text/markdown")
    |> put_resp_header("content-disposition", ~s(attachment; filename="dosey-dagbog.md"))
    |> send_resp(:ok, markdown)
  end

  defp format_day(%Day{} = day) do
    lines =
      [
        format_time_entry("Vågnede", day.wake_time),
        format_time_entry("Medicin", day.medicine_time),
        Enum.map(day.events, &format_event/1),
        format_time_entry("Sov", day.sleep_time)
      ]
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    Enum.join(["## #{Date.to_iso8601(day.date)}", "" | lines], "\n")
  end

  defp format_time_entry(_label, nil), do: nil
  defp format_time_entry(label, time), do: "* #{label}: #{format_time(time)}"

  defp format_event(%Event{} = event) do
    description =
      case event.text do
        nil -> event_type_label(event.event_type)
        "" -> event_type_label(event.event_type)
        text -> "#{event_type_label(event.event_type)} — #{text}"
      end

    "* #{description}#{format_event_range(event)}"
  end

  defp format_event_range(%Event{started_at_time: nil, ended_at_time: nil}), do: ""

  defp format_event_range(%Event{started_at_time: started_at, ended_at_time: nil}) do
    ": #{format_time(started_at)}"
  end

  defp format_event_range(%Event{started_at_time: nil, ended_at_time: ended_at}) do
    ": til #{format_time(ended_at)}"
  end

  defp format_event_range(%Event{started_at_time: started_at, ended_at_time: ended_at}) do
    ": #{format_time(started_at)} - #{format_time(ended_at)}"
  end

  defp format_time(%Time{} = time), do: Calendar.strftime(time, "%H:%M")

  defp event_type_label(:social), do: "Socialt"
  defp event_type_label(:meltdown), do: "Nedsmeltning"
  defp event_type_label(:meal), do: "Måltid"
  defp event_type_label(:school), do: "Skole"
  defp event_type_label(:activity), do: "Aktivitet"
  defp event_type_label(:trip), do: "Tur"
  defp event_type_label(:wake_attempt), do: "Vækning"
  defp event_type_label(:put_to_bed), do: "Putning"
  defp event_type_label(:other), do: "Andet"
end
