defmodule Dosey.AccountsTest do
  use Dosey.DataCase, async: true

  alias Dosey.Accounts
  alias Dosey.Accounts.UserRegistration

  describe "register_user/1" do
    test "creates a user with trimmed email and a hashed password" do
      assert {:ok, user} =
               Accounts.register_user(
                 UserRegistration.new(
                   email: " Parent@Example.COM ",
                   password: "correct horse battery staple"
                 )
               )

      assert is_binary(user.id)
      assert {:ok, _uuid} = Ecto.UUID.cast(user.id)

      assert is_binary(user.hashed_password)
      assert String.starts_with?(user.hashed_password, "$2b$04$")
      refute user.hashed_password == "correct horse battery staple"
      refute Map.has_key?(user, :password)

      assert user.email == "Parent@Example.COM"

      assert %DateTime{} = user.inserted_at
      assert %DateTime{} = user.updated_at
    end

    test "requires a valid email address" do
      assert {:error, changeset} =
               Accounts.register_user(
                 UserRegistration.new(
                   email: "not-an-email",
                   password: "correct horse battery staple"
                 )
               )

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "requires a sufficiently long password" do
      assert {:error, changeset} =
               Accounts.register_user(
                 UserRegistration.new(
                   email: "parent@example.com",
                   password: "short"
                 )
               )

      assert %{password: ["should be at least 8 character(s)"]} = errors_on(changeset)
    end

    test "requires unique email addresses case-insensitively" do
      assert {:ok, _user} =
               Accounts.register_user(
                 UserRegistration.new(
                   email: "parent@example.com",
                   password: "correct horse battery staple"
                 )
               )

      assert {:error, changeset} =
               Accounts.register_user(
                 UserRegistration.new(
                   email: "PARENT@example.com",
                   password: "another correct battery staple"
                 )
               )

      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "get_user/1" do
    test "returns the user for an existing id" do
      assert {:ok, registered_user} =
               Accounts.register_user(
                 UserRegistration.new(
                   email: "parent@example.com",
                   password: "correct horse battery staple"
                 )
               )

      assert user = Accounts.get_user(registered_user.id)
      assert user.id == registered_user.id
      assert user.email == registered_user.email
    end

    test "returns nil for an unknown id" do
      assert Accounts.get_user(Ecto.UUID.generate()) == nil
    end

    test "returns nil for invalid ids" do
      assert Accounts.get_user(nil) == nil
      assert Accounts.get_user("not-a-uuid") == nil
    end
  end

  describe "authenticate_user_by_email_and_password/2" do
    test "returns the user for a valid email and password" do
      assert {:ok, registered_user} =
               Accounts.register_user(
                 UserRegistration.new(
                   email: "parent@example.com",
                   password: "correct horse battery staple"
                 )
               )

      assert {:ok, authenticated_user} =
               Accounts.authenticate_user_by_email_and_password(
                 "PARENT@example.com",
                 "correct horse battery staple"
               )

      assert authenticated_user.id == registered_user.id
    end

    test "rejects an invalid password" do
      assert {:ok, _user} =
               Accounts.register_user(
                 UserRegistration.new(
                   email: "parent@example.com",
                   password: "correct horse battery staple"
                 )
               )

      assert :error =
               Accounts.authenticate_user_by_email_and_password(
                 "parent@example.com",
                 "wrong horse battery staple"
               )
    end
  end
end
