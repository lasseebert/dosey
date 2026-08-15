defmodule Dosey.Repo do
  use Ecto.Repo,
    otp_app: :dosey,
    adapter: Ecto.Adapters.Postgres
end
