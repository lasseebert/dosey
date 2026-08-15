defmodule Dosey.Accounts.User do
  use Dosey.Schema

  schema "users" do
    field(:email, :string)
    field(:hashed_password, :string)

    timestamps(type: :utc_datetime_usec)
  end
end
