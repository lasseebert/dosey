# Dosey Database

Dosey uses Ecto with PostgreSQL.

## Local Development

The default local database settings expect PostgreSQL on `localhost:5432` with:

```text
username: postgres
password: postgres
```

Start local PostgreSQL with Podman:

```sh
scripts/db-start.sh
```

This creates or starts a `dosey-postgres` container backed by a named Podman
volume called `dosey-postgres-data`.

Create and migrate the dev database:

```sh
mix ecto.setup
```

Reset it:

```sh
mix ecto.reset
```

Open a local `psql` shell:

```sh
scripts/db-shell.sh
```

Stop the local database:

```sh
scripts/db-stop.sh
```

## Test

The test environment uses `dosey_test` by default. Create it before running tests:

```sh
MIX_ENV=test mix ecto.create
```

Then run tests:

```sh
mix test
```

The temporary database wiring test creates and drops its own `test_notes` table.

## Production

Production reads `DATABASE_URL` from `/etc/dosey/dosey.env`.

DigitalOcean managed PostgreSQL requires TLS. By default, the app encrypts the
connection without verifying the server certificate. For certificate and
hostname verification, download the cluster CA certificate from DigitalOcean,
copy it to the server, and set:

```text
DATABASE_CA_CERT_PATH=/etc/dosey/postgres-ca.crt
```
