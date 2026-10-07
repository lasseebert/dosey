# Closing down Dosey

Use this checklist in order. Do not delete the database, droplet, DNS zone, or
Terraform state until the exports have been copied off DigitalOcean and tested.

Dosey contains private health and family information. Store every export in an
encrypted location, do not commit it to this repository, and avoid leaving an
unencrypted copy on the droplet or in a shared folder.

## 1. Find everything that is in use

- [x] Record the shutdown date and tell the other parent when Dosey will become
      read-only/unavailable.
- [ ] In DigitalOcean, inventory all resources in the `dosey` project and all
      resources tagged `dosey`, including anything created manually.
- [ ] Confirm the expected Terraform-managed resources are present: the
      `dosey` droplet, `dosey-postgres` managed PostgreSQL cluster, firewall,
      database firewall, SSH key, `dosey.dk` DNS zone, and its A, AAAA, and
      `www` CNAME records.
- [ ] Check separately for resources not present in `terraform/main.tf`, such as
      snapshots, backups, volumes, reserved IPs, load balancers, Spaces buckets,
      monitoring/uptime checks, alerts, and additional DNS records.
- [ ] Identify the registrar for `dosey.dk`, its renewal date, whether automatic
      renewal is enabled, and whether the domain is used for anything besides
      Dosey (especially email).
- [ ] Review bank/card statements and email receipts for other Dosey-related
      subscriptions or services not represented in this repository.

## 2. Make the final production export

- [ ] Choose an encrypted backup location with at least two independent copies.
- [ ] Ensure a PostgreSQL 18 client (`pg_dump`, `psql`, and `createdb`) is
      available on the machine performing the export. Using the same major
      version as production avoids compatibility surprises.
- [ ] Put Dosey into a maintenance window, then stop the application service on
      the droplet so no records can be added after the final export:

      ```sh
      ssh root@dosey.dk systemctl stop dosey
      ```

- [ ] Export the complete database as plain SQL. Run `pg_dump` from a trusted
      machine that can reach the database, using the production connection URI
      as `DATABASE_URL`:

      ```sh
      umask 077
      pg_dump --dbname="$DATABASE_URL" \
        --format=plain --no-owner --no-privileges \
        --file="dosey-production-$(date -u +%Y-%m-%d).sql"
      ```

      The full dump is the authoritative backup. It includes the schema,
      migrations, users (including password hashes), diary days, and diary
      events. Do not paste the connection URI into shell history. The managed
      database currently only trusts the droplet, so either run this there and
      securely copy the result off it, or temporarily add the exporting
      machine as a trusted source and remove that rule immediately afterward.

- [ ] Also export human-readable CSV files for future use without Phoenix or
      PostgreSQL. Include stable IDs and timestamps so relationships and event
      ordering are preserved:

      ```sh
      mkdir dosey-production-csv
      psql "$DATABASE_URL" --set=ON_ERROR_STOP=1 \
        --command="\copy (SELECT id, date, wake_time, medicine_time, sleep_time, inserted_at, updated_at FROM diary_days ORDER BY date, id) TO 'dosey-production-csv/diary_days.csv' WITH (FORMAT csv, HEADER true)"
      psql "$DATABASE_URL" --set=ON_ERROR_STOP=1 \
        --command="\copy (SELECT id, day_id, event_type, text, started_at_time, ended_at_time, inserted_at, updated_at FROM diary_events ORDER BY day_id, inserted_at, id) TO 'dosey-production-csv/diary_events.csv' WITH (FORMAT csv, HEADER true)"
      psql "$DATABASE_URL" --set=ON_ERROR_STOP=1 \
        --command="\copy (SELECT id, email, hashed_password, inserted_at, updated_at FROM users ORDER BY id) TO 'dosey-production-csv/users.csv' WITH (FORMAT csv, HEADER true)"
      ```

- [ ] Record database row counts alongside the export:

      ```sh
      psql "$DATABASE_URL" --tuples-only --no-align --set=ON_ERROR_STOP=1 \
        --command="SELECT 'users', count(*) FROM users UNION ALL SELECT 'diary_days', count(*) FROM diary_days UNION ALL SELECT 'diary_events', count(*) FROM diary_events ORDER BY 1;" \
        > dosey-production-row-counts.txt
      ```

- [ ] Generate checksums for the SQL and CSV files (for example with
      `sha256sum`) and store the checksum file with the backup.
- [ ] Open the CSV files and spot-check old and recent dates, Danish characters,
      multiline notes, commas, and event times.
- [ ] Restore the SQL dump into a temporary empty PostgreSQL 18 database and
      compare its table row counts with `dosey-production-row-counts.txt`.
- [ ] Confirm both parents can access the durable backup and document where it
      is stored and how it can be decrypted/restored.
- [ ] Make the second independent encrypted copy and verify its checksums.
- [ ] Keep the application stopped after the verified final export. If it must
      be restarted, repeat the final export before teardown.

## 3. Preserve what may be useful later

- [ ] Preserve this Git repository, including migrations and the exact commit
      deployed at shutdown; the database export alone does not explain all
      application behavior.
- [ ] Save a copy of the Terraform state securely before destroying resources.
      It may contain sensitive infrastructure data and must not be committed.
- [ ] Record the PostgreSQL version (currently 18), export date, Dosey commit,
      row counts, checksums, and brief restore instructions next to the backup.
- [ ] Decide on a retention period. Because this is health-related data, retain
      only what the family actually wants and securely delete redundant working
      copies after verification.

## 4. Remove DigitalOcean infrastructure

- [ ] Run `terraform -chdir=terraform plan -destroy` and review every proposed
      deletion. Reconcile it against the DigitalOcean inventory before applying.
- [ ] Only after the exports and restore test pass, run:

      ```sh
      terraform -chdir=terraform destroy
      ```

- [ ] In the DigitalOcean control panel, confirm the droplet, managed database,
      firewalls, DNS zone, DNS records, and managed SSH key are gone.
- [ ] Manually delete any resources Terraform did not manage, including database
      pools, snapshots/backups, volumes, reserved IPs, load balancers, Spaces,
      monitoring checks, and alerts. Check whether retained backups or snapshots
      continue to incur charges.
- [ ] Check the DigitalOcean Billing page for projected remaining charges and
      download the final invoices/receipts needed for personal records.
- [ ] Revoke the DigitalOcean API token used by Terraform if it is not needed
      elsewhere. Remove local Dosey-only credentials after preserving any state
      or records that were intentionally retained.
- [ ] After the final invoice settles, consider closing the DigitalOcean account
      only if it has no unrelated projects or resources.

## 5. Retire DNS and the domain

- [ ] Before removing DNS, confirm `dosey.dk` is not used for email or another
      service. Preserve or replace any MX, TXT, SPF, DKIM, DMARC, verification,
      or other records that still matter.
- [ ] Confirm the DigitalOcean DNS zone was removed by Terraform. If DNS is
      hosted elsewhere or was not in Terraform state, remove it at that provider
      and cancel any paid DNS plan.
- [ ] At the domain registrar, disable automatic renewal for `dosey.dk` and
      remove saved payment details if appropriate.
- [ ] Do not delete a registrar account containing other domains. Record the
      expiry/release date and expect the domain to remain registered until then.
- [ ] Decide whether letting the domain expire creates an impersonation or
      privacy risk. Keeping the domain parked without hosting may be safer if old
      bookmarks, password managers, or emails still associate it with the family.
- [ ] Remove stale `dosey.dk` entries from password managers and bookmarks after
      the site is gone.

## 6. Final verification and cleanup

- [ ] Confirm `https://dosey.dk` and `https://www.dosey.dk` no longer serve the
      application once DNS caches have expired.
- [ ] Confirm DigitalOcean shows no billable Dosey resources and the registrar
      will not renew the domain.
- [ ] Search local machines and cloud storage for temporary unencrypted database
      exports, connection strings, Terraform variable files, and copied server
      environment files; securely remove those that are no longer needed.
- [ ] Revoke or remove Dosey-only SSH keys and clean stale SSH `known_hosts`
      entries if desired.
- [ ] Note that the Let's Encrypt certificate and Certbot installation live on
      the destroyed droplet and have no separate subscription to cancel.
- [ ] Perform one final restore/checksum test from the retained backup, then mark
      this checklist complete with the date and backup location.

Shutdown completed on: ____________________

Verified backup location(s): ________________________________________________

Verified by: ____________________
