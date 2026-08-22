defmodule Dosey.Repo.Migrations.AddTripDiaryEventType do
  use Ecto.Migration

  def up do
    execute("ALTER TYPE diary_event_type ADD VALUE 'trip'")
  end

  def down do
    execute(
      """
      CREATE TYPE diary_event_type_new AS ENUM (
        'social',
        'meltdown',
        'meal',
        'wake_attempt',
        'put_to_bed',
        'other',
        'school',
        'activity'
      )
      """
    )

    execute("""
    ALTER TABLE diary_events
    ALTER COLUMN event_type TYPE diary_event_type_new
    USING event_type::text::diary_event_type_new
    """)

    execute("DROP TYPE diary_event_type")
    execute("ALTER TYPE diary_event_type_new RENAME TO diary_event_type")
  end
end
