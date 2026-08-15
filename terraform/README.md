# Dosey Terraform

Terraform config for the DigitalOcean infrastructure used by Dosey.

## Requirements

- Terraform installed locally
- A DigitalOcean API token in `secrets.auto.tfvars`
- A local SSH public key at `~/.ssh/dosey.pub`

The secrets files should look like this:

```hcl
digitalocean_token = "dop_v1_..."
```

## First-time setup

Initialize Terraform providers:

```sh
terraform init
```

## Validate

Check formatting:

```sh
terraform fmt -check
```

Validate the configuration:

```sh
terraform validate
```

## Plan

Create a plan:

```sh
terraform plan
```

## Apply

Create or update the infrastructure:

```sh
terraform apply
```

After creating the managed database, copy the private connection URI into
`/etc/dosey/dosey.env` on the server as `DATABASE_URL`:

```sh
terraform output -raw database_private_uri
```

## Destroy

Destroy the infrastructure managed by this Terraform config:

```sh
terraform destroy
```
