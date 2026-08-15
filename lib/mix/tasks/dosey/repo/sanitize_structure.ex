defmodule Mix.Tasks.Dosey.Repo.SanitizeStructure do
  @moduledoc """
  Removes non-deterministic pg_dump restrict lines from a structure SQL file.
  """

  use Mix.Task

  @shortdoc "Removes pg_dump restrict lines from priv/repo/structure.sql"
  @default_path "priv/repo/structure.sql"

  @impl Mix.Task
  def run(args) do
    path = List.first(args) || @default_path

    path
    |> File.read!()
    |> String.replace(~r/^\\(?:un)?restrict\s+.*\n+/m, "")
    |> then(&File.write!(path, &1))
  end
end
