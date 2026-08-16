defmodule Dosey.Repo.Migrations.ReindexDiaryEventsForInsertedAtOrder do
  use Ecto.Migration

  def change do
    drop(index(:diary_events, [:day_id, :started_at_time, :inserted_at]))
    create(index(:diary_events, [:day_id, :inserted_at]))
  end
end
