# Dosey

Dosey is a private family medicine diary for tracking a child's medications,
sleep habits, and general wellbeing. It is intended for day-to-day use by two
parents who need a shared, reliable view of what happened and when.

## High-Level Architecture

Dosey is planned as a single Phoenix application backed by a relational
database. The frontend should be mobile-first and app-like, with the main user
experience delivered directly by Phoenix rather than through a separately
maintained frontend application.

The architecture should favor fast iteration, a small operational footprint,
and clear server-side domain logic. A separate API or native client can be added
later if the project grows to need it.

## Language

All user-facing application text must be written in Danish.

## Development workflow for agents

When implementing a feature, code change, bug fix in the backend, always use TDD:

1. Write one or more failing tests that describe the desired behavior.
2. Run all new tests to verify that they fail for the correct reasons.
  a. If the tests fail for the wrong reasons, fix the tests and repeat step 1
3. Wait for review and approval of the tests from me (the human)
4. Now focus only one a single test failure:
  a. Run the failing test, verify that it still fails for the correct reason
  b. Implement the minimum code change to make the test pass
5. Repeat step 4 for each newly added test
6. Run all tests to verify that they all pass
7. Look for refactoring opportunities and implement them, making sure to run all tests after each change

Untested code is no code. Tests written after the code is no test and thus no code.

## Structs

For internal non-Ecto structs, always use `typedstruct` instead of hand-written
`defstruct` and `@type t` definitions.

## Ecto schemas and changesets

Ecto schema modules should define database-backed data structures only, and
methods that operate directly on those structures.
Changeset functions belong in the context module that owns the workflow, not in
the schema module.
