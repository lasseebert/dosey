defmodule Dosey.Diary.Event do
  use Dosey.Schema

  alias Dosey.Diary.Day

  @event_types [
    :social,
    :meltdown,
    :meal,
    :school,
    :activity,
    :wake_attempt,
    :put_to_bed,
    :other
  ]

  schema "diary_events" do
    field(:event_type, Ecto.Enum, values: @event_types)
    field(:text, :string)
    field(:started_at_time, :time)
    field(:ended_at_time, :time)

    belongs_to(:day, Day)

    timestamps(type: :utc_datetime_usec)
  end

  def event_types, do: @event_types
end
