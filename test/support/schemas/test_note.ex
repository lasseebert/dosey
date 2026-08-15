defmodule Dosey.TestNote do
  use Ecto.Schema

  schema "test_notes" do
    field(:body, :string)
  end
end
