defmodule Dosey.DataCase do
  @moduledoc """
  This module defines the test case to be used by tests that need database access.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Dosey.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Dosey.DataCase
    end
  end

  setup tags do
    Dosey.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Dosey.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
