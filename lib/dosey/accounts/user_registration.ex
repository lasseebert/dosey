defmodule Dosey.Accounts.UserRegistration do
  @moduledoc """
  Typed input for registering a user.
  """

  use TypedStruct

  typedstruct enforce: true do
    field(:email, String.t() | nil)
    field(:password, String.t() | nil)
  end

  def new(attrs) when is_list(attrs) do
    %__MODULE__{
      email: Keyword.get(attrs, :email),
      password: Keyword.get(attrs, :password)
    }
  end

  def new(%{email: email, password: password}) do
    %__MODULE__{
      email: email,
      password: password
    }
  end
end
