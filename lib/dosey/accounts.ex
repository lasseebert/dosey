defmodule Dosey.Accounts do
  @moduledoc """
  Accounts context for registering and authenticating users.
  """

  import Ecto.Changeset
  import Ecto.Query

  alias Dosey.Accounts.User
  alias Dosey.Accounts.UserRegistration
  alias Dosey.Repo
  alias Ecto.Changeset

  @spec register_user(UserRegistration.t()) :: {:ok, User.t()} | {:error, Changeset.t()}
  def register_user(%UserRegistration{} = registration) do
    %User{}
    |> registration_changeset(registration)
    |> Repo.insert()
  end

  @spec authenticate_user_by_email_and_password(String.t(), String.t()) ::
          {:ok, User.t()} | :error
  def authenticate_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    email = trim(email)

    User
    |> where([user], user.email == ^email)
    |> Repo.one()
    |> verify_password(password)
  end

  def authenticate_user_by_email_and_password(_email, _password), do: :error

  defp registration_changeset(%User{} = user, %UserRegistration{} = registration) do
    email = trim(registration.email)
    password = registration.password

    user
    |> cast(%{email: email}, [:email])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_password(password)
    |> unique_constraint(:email)
    |> put_password_hash(password)
  end

  defp trim(value) when is_binary(value), do: String.trim(value)
  defp trim(value) when is_nil(value), do: nil

  defp validate_password(changeset, password) when is_binary(password) do
    if String.length(password) >= 8 do
      changeset
    else
      add_error(changeset, :password, "should be at least %{count} character(s)", count: 8)
    end
  end

  defp validate_password(changeset, password) when is_nil(password) do
    add_error(changeset, :password, "can't be blank")
  end

  defp put_password_hash(%Changeset{valid?: true} = changeset, password) do
    put_change(changeset, :hashed_password, Bcrypt.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset, _password), do: changeset

  defp verify_password(%User{} = user, password) do
    if Bcrypt.verify_pass(password, user.hashed_password) do
      {:ok, user}
    else
      :error
    end
  end

  defp verify_password(nil, _password) do
    Bcrypt.no_user_verify()
    :error
  end
end
