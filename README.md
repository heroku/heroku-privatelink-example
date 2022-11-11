# Provision Heroku PrivateLink with Terraform

An example of setting up Heroku Postgres via PrivateLink. This is only meant to
show how to create a connection between a Heroku PostgreSQL addon and a customer-owned
VPC. This can serve as a template for production use-cases but make sure you follow
your organization's best practices around security.

## Prerequisites

* Logged into heroku via `heroku login`.
* Logged into an AWS account via `aws configure` or environment variables.

## Setup

You'll need to know the following values. This can either be added to a
`terraform.tfvars` file or exported to your shell's environment.

* heroku_app_name
* heroku_organization_name
* heroku_private_space_name
* heroku_postgresql_plan (defaults to `heroku-postgresql:private-0`)
* heroku_region
* private_link_aws_account_ids

## Provision

Provisioning happens in a single step. This will compile a test program, provision
Heroku apps, Heroku addons, AWS resources, establish a PrivateLink between the
Heroku addon and the configured AWS account, and run a Lambda to ensure both PostgreSQL
and Pgbouncer are available.

```shell
$ ./deploy.sh
```

### Outputs

You will see the following output if terraform configs are successfully applied.

```
Outputs:

privatelink_pgbouncer_status = "Successfully connected."
privatelink_postgres_status = "Successfully connected."
```

## Links

* [Connecting to a Private or Shield Heroku Postgres Database via PrivateLink](https://devcenter.heroku.com/articles/heroku-postgres-via-privatelink)
