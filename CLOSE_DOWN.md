# Closing down Dosey

Use this checklist in order. Do not delete the database, droplet, DNS zone, or
Terraform state until the export has been downloaded and verified.

Dosey contains private health and family information. Store every export in an
encrypted location, do not commit it to this repository, and avoid leaving an
unencrypted copy on the droplet or in a shared folder.

## 1. Find everything that is in use

- [x] Shutdown date: 7 October 2026. The other parent has been notified when
      Dosey will become read-only/unavailable.
- [x] Inventoried all resources in the `dosey` project and all resources tagged
      `dosey` in DigitalOcean on 7 October 2026.
- [x] Confirmed in DigitalOcean on 7 October 2026: the expected
      Terraform-managed resources are present—the
      `dosey` droplet, `dosey-postgres` managed PostgreSQL cluster, firewall,
      database firewall, SSH key, `dosey.dk` DNS zone, and its A, AAAA, and
      `www` CNAME records.
- [x] Confirmed on 7 October 2026 that there are no additional resources outside
      `terraform/main.tf`, such as snapshots, backups, volumes, reserved IPs,
      load balancers, Spaces buckets, monitoring/uptime checks, alerts, or
      additional DNS records.
- [x] Registrar and billing provider identified: DNS Platform. Domain:
      `dosey.dk`; registrant: `LSE94-DK`; created: 12 August 2026; expires:
      12 August 2027.
- [x] Treat automatic renewal as enabled unless DNS Platform confirms otherwise;
      it must be explicitly disabled or cancelled during domain retirement.
- [x] Confirmed that `dosey.dk` is not used for email or anything besides Dosey.
- [x] Reviewed known services and payment records on 10 October 2026; no other
      Dosey-related paid subscriptions or services were identified.

## 2. Make the final production export

- [x] Downloaded the complete production diary in human-readable Markdown from
      the authenticated `/export` endpoint on 10 October 2026.
- [x] Reviewed the Markdown export, including its dates, Danish characters,
      notes, and event times.
- [x] Stored the Markdown export securely in Lasse's Google Drive.
- [x] Decided that no additional copy of the Markdown export is needed.
- [x] Confirmed that both parents can access the securely stored Markdown file.
- [x] Decided that no checksum is needed for the Markdown file.
- [x] The application can no longer receive records because its DigitalOcean
      droplet was destroyed through Terraform on 10 October 2026. The manual
      stop command was therefore unnecessary:

      ```sh
      ssh root@dosey.dk systemctl stop dosey
      ```

- [x] The application remained unavailable after the final export because its
      infrastructure was destroyed.

## 3. Preserve what may be useful later

- [x] Preserve this Git repository, including migrations and the shutdown
      history, in the private GitHub repository and locally on the owner's
      machine.
- [x] Decided not to retain a separate copy of the Terraform state after
      destroying the infrastructure.
- [x] Export date recorded: 10 October 2026.
- [x] Decided not to record the deployed commit or a separate description of
      the Markdown format with the backup.
- [x] Decided not to set a retention period for the securely stored Markdown
      export.

## 4. Remove DigitalOcean infrastructure

- [x] Destroyed the Terraform-managed DigitalOcean resources on 10 October 2026
      with:

      ```sh
      terraform -chdir=terraform destroy
      ```

- [x] Verified in the DigitalOcean control panel that the Terraform-managed
      droplet, managed database, firewalls, DNS zone, DNS records, and SSH key
      are gone.
- [x] No manually managed DigitalOcean resources required deletion; the earlier
      inventory found none outside Terraform.
- [x] Decided that no separate DigitalOcean billing check or statement download
      is needed.
- [x] Deleted the Dosey DigitalOcean API token used by Terraform.
- [x] Keep the DigitalOcean account open because it is used for unrelated
      projects and resources.

## 5. Retire DNS and the domain

- [x] Confirmed that `dosey.dk` is not used for email or any service other than
      Dosey; no MX, TXT, SPF, DKIM, DMARC, or verification records need to be
      preserved.
- [x] The DigitalOcean DNS zone and its records were removed through Terraform
      on 10 October 2026. No separate paid DNS hosting was identified.
- [x] Cancelled `dosey.dk` through DNS Platform; it will not renew.
## 6. Final verification and cleanup

- [x] Confirmed through the domain cancellation that DNS Platform will not renew
      `dosey.dk`.

Shutdown completed on: 10 October 2026

Verified backup location(s): Lasse's Google Drive

Verified by: Lasse
