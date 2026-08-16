defmodule Dosey.Diary do
  @moduledoc """
  Diary context for days and timeline events.
  """

  import Ecto.Changeset
  import Ecto.Query

  alias Dosey.Diary.Day
  alias Dosey.Diary.Event
  alias Dosey.Repo
  alias Ecto.Changeset

  @spec get_day(Date.t()) :: Day.t() | nil
  def get_day(%Date{} = date) do
    Day
    |> where([day], day.date == ^date)
    |> preload(events: ^events_query())
    |> Repo.one()
  end

  def get_day(_date), do: nil

  @spec create_day(Date.t() | nil) :: {:ok, Day.t()} | {:error, Changeset.t()}
  def create_day(date) when is_struct(date, Date) or is_nil(date) do
    %Day{}
    |> create_day_changeset(date)
    |> Repo.insert()
  end

  @spec update_day(Day.t(), map()) :: {:ok, Day.t()} | {:error, Changeset.t()}
  def update_day(%Day{} = day, attrs) when is_map(attrs) do
    day
    |> update_day_changeset(attrs)
    |> Repo.update()
  end

  @spec add_event(Day.t(), map()) :: {:ok, Event.t()} | {:error, Changeset.t()}
  def add_event(%Day{} = day, attrs) when is_map(attrs) do
    %Event{}
    |> create_event_changeset(day, attrs)
    |> Repo.insert()
  end

  @spec update_event(Event.t(), map()) :: {:ok, Event.t()} | {:error, Changeset.t()}
  def update_event(%Event{} = event, attrs) when is_map(attrs) do
    event
    |> update_event_changeset(attrs)
    |> Repo.update()
  end

  @spec delete_event(Event.t()) :: {:ok, Event.t()} | {:error, Changeset.t()}
  def delete_event(%Event{} = event) do
    Repo.delete(event)
  end

  defp create_day_changeset(%Day{} = day, date) do
    day
    |> change(date: date)
    |> validate_required([:date])
    |> unique_constraint(:date)
  end

  defp update_day_changeset(%Day{} = day, attrs) do
    day
    |> cast(attrs, [:wake_time, :medicine_time, :sleep_time])
  end

  defp create_event_changeset(%Event{} = event, %Day{} = day, attrs) do
    event
    |> cast(attrs, [:event_type, :text, :started_at_time, :ended_at_time])
    |> put_assoc(:day, day)
    |> validate_required([:day, :event_type])
  end

  defp update_event_changeset(%Event{} = event, attrs) do
    event
    |> cast(attrs, [:event_type, :text, :started_at_time, :ended_at_time])
    |> validate_required([:event_type])
  end

  defp events_query do
    from(event in Event,
      order_by: [
        asc: fragment("? IS NULL", event.started_at_time),
        asc: event.started_at_time,
        asc: event.inserted_at
      ]
    )
  end
end
