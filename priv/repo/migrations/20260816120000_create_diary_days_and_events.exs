defmodule Dosey.Repo.Migrations.CreateDiaryDaysAndEvents do
  use Ecto.Migration

  def change do
    execute(
      """
      CREATE TYPE diary_event_type AS ENUM (
        'social',
        'meltdown',
        'meal',
        'wake_attempt',
        'put_to_bed',
        'other'
      )
      """,
      "DROP TYPE diary_event_type"
    )

    create table(:diary_days) do
      add :date, :date, null: false
      add :wake_time, :time, precision: 0
      add :medicine_time, :time, precision: 0
      add :sleep_time, :time, precision: 0

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:diary_days, [:date])

    create table(:diary_events) do
      add :day_id, references(:diary_days, on_delete: :delete_all), null: false
      add :event_type, :diary_event_type, null: false
      add :text, :text
      add :started_at_time, :time, precision: 0
      add :ended_at_time, :time, precision: 0

      timestamps(type: :utc_datetime_usec)
    end

    create index(:diary_events, [:day_id])
    create index(:diary_events, [:day_id, :started_at_time, :inserted_at])
  end
end
