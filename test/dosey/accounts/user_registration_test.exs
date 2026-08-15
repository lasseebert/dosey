defmodule Dosey.Accounts.UserRegistrationTest do
  use ExUnit.Case, async: true

  alias Dosey.Accounts.UserRegistration

  describe "new/1" do
    test "only accepts atom keys" do
      assert_raise FunctionClauseError, fn ->
        apply(UserRegistration, :new, [
          %{
            "email" => "parent@example.com",
            "password" => "correct horse battery staple"
          }
        ])
      end
    end
  end
end
