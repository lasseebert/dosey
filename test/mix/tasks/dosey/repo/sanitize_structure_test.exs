defmodule Mix.Tasks.Dosey.Repo.SanitizeStructureTest do
  use ExUnit.Case, async: false

  @task "dosey.repo.sanitize_structure"

  test "removes pg_dump restrict lines from a structure file" do
    path = Path.join(System.tmp_dir!(), "dosey-structure-#{System.unique_integer()}.sql")

    File.write!(path, """
    --
    -- PostgreSQL database dump
    --

    \\restrict random

    CREATE TABLE public.users (
        id uuid NOT NULL
    );

    \\unrestrict random

    INSERT INTO public."schema_migrations" (version) VALUES (20260815120000);
    """)

    Mix.Task.reenable(@task)
    Mix.Task.run(@task, [path])

    assert File.read!(path) == """
           --
           -- PostgreSQL database dump
           --

           CREATE TABLE public.users (
               id uuid NOT NULL
           );

           INSERT INTO public."schema_migrations" (version) VALUES (20260815120000);
           """
  end
end
