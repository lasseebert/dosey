defmodule Dosey.DiaryTest do
  use Dosey.DataCase, async: true

  alias Dosey.Diary

  describe "create_day/1" do
    test "creates a day with only a date" do
      assert {:ok, day} = Diary.create_day(~D[2026-08-16])

      assert is_binary(day.id)
      assert {:ok, _uuid} = Ecto.UUID.cast(day.id)

      assert day.date == ~D[2026-08-16]
      assert day.wake_time == nil
      assert day.medicine_time == nil
      assert day.sleep_time == nil

      assert %DateTime{} = day.inserted_at
      assert %DateTime{} = day.updated_at
    end

    test "requires a date" do
      assert {:error, changeset} = Diary.create_day(nil)

      assert %{date: ["can't be blank"]} = errors_on(changeset)
    end

    test "only accepts a date input" do
      assert_raise FunctionClauseError, fn ->
        apply(Diary, :create_day, [%{date: ~D[2026-08-16]}])
      end
    end

    test "requires unique dates" do
      assert {:ok, _day} = Diary.create_day(~D[2026-08-16])

      assert {:error, changeset} = Diary.create_day(~D[2026-08-16])

      assert %{date: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "update_day/2" do
    test "updates quick summary times" do
      assert {:ok, day} = Diary.create_day(~D[2026-08-16])

      assert {:ok, updated_day} =
               Diary.update_day(day, %{
                 wake_time: ~T[07:20:00],
                 medicine_time: ~T[07:50:00],
                 sleep_time: ~T[20:15:00]
               })

      assert updated_day.wake_time == ~T[07:20:00]
      assert updated_day.medicine_time == ~T[07:50:00]
      assert updated_day.sleep_time == ~T[20:15:00]
    end

    test "persists time fields with seconds precision" do
      assert {:ok, day} = Diary.create_day(~D[2026-08-17])

      assert {:ok, _updated_day} =
               Diary.update_day(day, %{
                 wake_time: ~T[07:05:00],
                 medicine_time: ~T[07:35:00],
                 sleep_time: ~T[20:05:00]
               })

      assert reloaded_day = Diary.get_day(day.date)
      assert reloaded_day.wake_time == ~T[07:05:00]
      assert reloaded_day.medicine_time == ~T[07:35:00]
      assert reloaded_day.sleep_time == ~T[20:05:00]
    end

    test "truncates subsecond quick summary times to seconds precision" do
      assert {:ok, day} = Diary.create_day(~D[2026-08-17])

      assert {:ok, _updated_day} =
               Diary.update_day(day, %{
                 wake_time: ~T[07:05:00.999],
                 medicine_time: ~T[07:35:00.001],
                 sleep_time: ~T[20:05:00.500]
               })

      assert reloaded_day = Diary.get_day(day.date)
      assert reloaded_day.wake_time == ~T[07:05:00]
      assert reloaded_day.medicine_time == ~T[07:35:00]
      assert reloaded_day.sleep_time == ~T[20:05:00]
    end

    test "accepts quick summary times with seconds precision" do
      assert {:ok, day} = Diary.create_day(~D[2026-08-16])

      assert {:ok, _updated_day} =
               Diary.update_day(day, %{
                 wake_time: ~T[07:05:42],
                 medicine_time: ~T[07:35:15],
                 sleep_time: ~T[20:05:59]
               })

      assert reloaded_day = Diary.get_day(day.date)
      assert reloaded_day.wake_time == ~T[07:05:42]
      assert reloaded_day.medicine_time == ~T[07:35:15]
      assert reloaded_day.sleep_time == ~T[20:05:59]
    end
  end

  describe "add_event/2" do
    test "adds a typed event without text or times" do
      assert {:ok, day} = Diary.create_day(~D[2026-08-16])

      assert {:ok, event} =
               Diary.add_event(day, %{
                 event_type: :put_to_bed
               })

      assert event.day_id == day.id
      assert event.event_type == :put_to_bed
      assert event.text == nil
      assert event.started_at_time == nil
      assert event.ended_at_time == nil
    end

    test "adds a typed event with start and end times" do
      assert {:ok, day} = Diary.create_day(~D[2026-08-16])

      assert {:ok, event} =
               Diary.add_event(day, %{
                 event_type: :social,
                 text: "Went for a trip to the lake",
                 started_at_time: ~T[10:15:00],
                 ended_at_time: ~T[12:30:00]
               })

      assert event.event_type == :social
      assert event.text == "Went for a trip to the lake"
      assert event.started_at_time == ~T[10:15:00]
      assert event.ended_at_time == ~T[12:30:00]
    end

    test "truncates subsecond event times to seconds precision" do
      assert {:ok, day} = Diary.create_day(~D[2026-08-16])

      assert {:ok, event} =
               Diary.add_event(day, %{
                 event_type: :social,
                 started_at_time: ~T[10:15:00.999],
                 ended_at_time: ~T[12:30:00.001]
               })

      assert event.started_at_time == ~T[10:15:00]
      assert event.ended_at_time == ~T[12:30:00]
    end

    test "adds a typed event with only a start time" do
      assert {:ok, day} = Diary.create_day(~D[2026-08-16])

      assert {:ok, event} =
               Diary.add_event(day, %{
                 event_type: :meal,
                 text: "Complained about the taste",
                 started_at_time: ~T[07:45:00]
               })

      assert event.started_at_time == ~T[07:45:00]
      assert event.ended_at_time == nil
    end

    test "adds school and activity events" do
      assert {:ok, day} = Diary.create_day(~D[2026-08-16])

      assert {:ok, school_event} =
               Diary.add_event(day, %{
                 event_type: :school,
                 text: "God aflevering"
               })

      assert {:ok, activity_event} =
               Diary.add_event(day, %{
                 event_type: :activity,
                 text: "Fodbold"
               })

      assert school_event.event_type == :school
      assert activity_event.event_type == :activity
    end

    test "rejects unknown event types" do
      assert {:ok, day} = Diary.create_day(~D[2026-08-16])

      assert {:error, changeset} =
               Diary.add_event(day, %{
                 event_type: :screen_time,
                 text: "Watched TV"
               })

      assert %{event_type: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts event times with seconds precision" do
      assert {:ok, day} = Diary.create_day(~D[2026-08-16])

      assert {:ok, event} =
               Diary.add_event(day, %{
                 event_type: :social,
                 started_at_time: ~T[10:15:30],
                 ended_at_time: ~T[12:30:45]
               })

      assert event.started_at_time == ~T[10:15:30]
      assert event.ended_at_time == ~T[12:30:45]
    end
  end

  describe "get_day/1" do
    test "returns a day with events ordered by insertion time" do
      assert {:ok, day} = Diary.create_day(~D[2026-08-16])

      assert {:ok, first_event} =
               Diary.add_event(day, %{
                 event_type: :other,
                 text: "A note without a specific time"
               })

      assert {:ok, second_event} =
               Diary.add_event(day, %{
                 event_type: :put_to_bed,
                 started_at_time: ~T[20:00:00]
               })

      assert {:ok, third_event} =
               Diary.add_event(day, %{
                 event_type: :wake_attempt,
                 started_at_time: ~T[07:00:00]
               })

      assert reloaded_day = Diary.get_day(~D[2026-08-16])

      assert Enum.map(reloaded_day.events, & &1.id) == [
               first_event.id,
               second_event.id,
               third_event.id
             ]
    end

    test "returns nil for a date without a day" do
      assert Diary.get_day(~D[2026-08-16]) == nil
    end
  end

  describe "get_or_create_day/1" do
    test "returns an existing day for the date" do
      assert {:ok, day} = Diary.create_day(~D[2026-08-16])

      assert {:ok, existing_day} = Diary.get_or_create_day(~D[2026-08-16])
      assert existing_day.id == day.id
    end

    test "creates a day when the date does not exist" do
      assert {:ok, day} = Diary.get_or_create_day(~D[2026-08-16])

      assert day.date == ~D[2026-08-16]
      assert Diary.get_day(~D[2026-08-16]).id == day.id
    end

    test "returns the existing day when the date already exists" do
      assert {:ok, day} = Diary.create_day(~D[2026-08-16])

      assert {:ok, existing_day} = Diary.get_or_create_day(~D[2026-08-16])
      assert existing_day.id == day.id
    end
  end

  describe "list_days/2" do
    test "returns existing days in the calendar range ordered newest first with events preloaded" do
      assert {:ok, older_day} = Diary.create_day(~D[2026-08-14])
      assert {:ok, newer_day} = Diary.create_day(~D[2026-08-16])
      assert {:ok, event} = Diary.add_event(older_day, %{event_type: :meal})

      assert [returned_newer_day, returned_older_day] = Diary.list_days(~D[2026-08-16], 3)
      assert returned_newer_day.id == newer_day.id
      assert returned_older_day.id == older_day.id
      assert Enum.map(returned_older_day.events, & &1.id) == [event.id]
    end
  end

  describe "update_event/2" do
    test "updates event type, text, and times" do
      assert {:ok, day} = Diary.create_day(~D[2026-08-16])

      assert {:ok, event} =
               Diary.add_event(day, %{
                 event_type: :social
               })

      assert {:ok, updated_event} =
               Diary.update_event(event, %{
                 event_type: :meltdown,
                 text: "Medium meltdown, quick recovery",
                 started_at_time: ~T[16:10:00],
                 ended_at_time: ~T[16:25:00]
               })

      assert updated_event.event_type == :meltdown
      assert updated_event.text == "Medium meltdown, quick recovery"
      assert updated_event.started_at_time == ~T[16:10:00]
      assert updated_event.ended_at_time == ~T[16:25:00]
    end

    test "accepts event updates with seconds precision" do
      assert {:ok, day} = Diary.create_day(~D[2026-08-16])
      assert {:ok, event} = Diary.add_event(day, %{event_type: :social})

      assert {:ok, updated_event} =
               Diary.update_event(event, %{
                 started_at_time: ~T[16:10:01],
                 ended_at_time: ~T[16:20:59]
               })

      assert updated_event.started_at_time == ~T[16:10:01]
      assert updated_event.ended_at_time == ~T[16:20:59]
    end
  end

  describe "delete_event/1" do
    test "deletes an event" do
      assert {:ok, day} = Diary.create_day(~D[2026-08-16])
      assert {:ok, event} = Diary.add_event(day, %{event_type: :put_to_bed})

      assert {:ok, deleted_event} = Diary.delete_event(event)
      assert deleted_event.id == event.id

      assert reloaded_day = Diary.get_day(day.date)
      assert reloaded_day.events == []
    end
  end
end
