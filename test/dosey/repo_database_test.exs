defmodule Dosey.RepoDatabaseTest do
  use ExUnit.Case, async: false

  setup do
    Dosey.Repo.query!(
      "CREATE TABLE IF NOT EXISTS test_notes (id bigserial primary key, body text)"
    )

    Dosey.Repo.delete_all(Dosey.TestNote)

    on_exit(fn ->
      Dosey.Repo.query!("DROP TABLE IF EXISTS test_notes")
    end)

    :ok
  end

  test "can persist and read a test schema through the repo" do
    note = Dosey.Repo.insert!(%Dosey.TestNote{body: "database is wired"})

    assert %Dosey.TestNote{body: "database is wired"} = Dosey.Repo.get!(Dosey.TestNote, note.id)
  end
end
