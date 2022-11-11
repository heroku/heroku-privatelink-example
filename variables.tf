locals {
  account_id = data.aws_caller_identity.current_aws_account.account_id
  vpc_endpoint_id = upper(replace(aws_vpc_endpoint.postgres_privatelink.id, "vpce-", ""))
  postgres_uri = lookup(heroku_app.pg_privatelink_test.all_config_vars, "DATABASE_ENDPOINT_${local.vpc_endpoint_id}_URL")
  pgbouncer_uri = lookup(heroku_app.pg_privatelink_test.all_config_vars, "DATABASE_ENDPOINT_${local.vpc_endpoint_id}_PGBOUNCER_URL")
  postgres_connection_result = jsondecode(data.aws_lambda_invocation.check_privatelink_postgres_connection.result)
  pgbouncer_connection_result = jsondecode(data.aws_lambda_invocation.check_privatelink_pgbouncer_connection.result)
}

variable "heroku_app_name" {
  description = "The name of the example Heroku app."
}

variable "heroku_organization_name" {
  description = "The Heroku organization to use for creating an example app."
}

variable "heroku_private_space_name" {
  description = "The private space to use for creating an example Heroku app."
}

variable "heroku_postgresql_plan" {
  description = "The Heroku PostgreSQL database plan to use for testing. Must be a Private or Shield plan."
  default = "heroku-postgresql:private-0"
}

variable "heroku_region" {
  default = "virginia"
  description = "The region to use for creating an example app in Heroku."
}

variable "private_link_aws_account_ids" {
  description = "A list of AWS account IDs to use when creating a PrivateLink endpoint."
}
