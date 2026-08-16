defmodule Dosey.Diary.Day do
  use Dosey.Schema

  alias Dosey.Diary.Event

  schema "diary_days" do
    field(:date, :date)
    field(:wake_time, :time)
    field(:medicine_time, :time)
    field(:sleep_time, :time)

    has_many(:events, Event)

    timestamps(type: :utc_datetime_usec)
  end
end
