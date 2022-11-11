provider "aws" {
  region = "us-east-1"
}

provider "herokux" {
  timeouts {
    privatelink_create_verify_timeout = 20
    privatelink_delete_verify_timeout = 20
    privatelink_allowed_acccounts_add_verify_timeout = 20
  }
}

data "aws_lambda_invocation" "check_privatelink_postgres_connection" {
  function_name = aws_lambda_function.test_privatelink_lambda.function_name
  depends_on = [
    aws_vpc_endpoint.postgres_privatelink
  ]

  input = jsonencode({
    postgres_uri = local.postgres_uri
  })
}

data "aws_lambda_invocation" "check_privatelink_pgbouncer_connection" {
  function_name = aws_lambda_function.test_privatelink_lambda.function_name
  depends_on = [
    aws_vpc_endpoint.postgres_privatelink
  ]

  input = jsonencode({
    postgres_uri = local.pgbouncer_uri
  })
}

data "aws_caller_identity" "current_aws_account" {}

data "archive_file" "pg_privatelink_test_zip_archive" {
  type        = "zip"
  source_file = "${path.module}/source/pg-test-privatelink/bin/pg-test-privatelink"
  output_path = "${path.module}/pg-test-privatelink.zip"
}

resource "heroku_app" "pg_privatelink_test" {
  name   = var.heroku_app_name
  region = var.heroku_region
  space = var.heroku_private_space_name

  organization {
    name = var.heroku_organization_name
  }

  buildpacks = [
    "heroku/ruby"
  ]
}

resource "heroku_addon" "database" {
  app_id = heroku_app.pg_privatelink_test.id
  plan   = var.heroku_postgresql_plan
}

resource "herokux_privatelink" "pg_privatelink" {
  addon_id = heroku_addon.database.id
  allowed_accounts = var.private_link_aws_account_ids
}

resource "aws_iam_policy" "pg_privatelink_user_policy" {
  name        = "PrivateLinkLambdaUserPolicy"
  path        = "/"
  description = ""
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ],
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "PrivateLinkLambdaRole"
  permissions_boundary = "arn:aws:iam::${local.account_id}:policy/PCSKPermissionsBoundary"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "pg_privatelink_role_to_policy" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.pg_privatelink_user_policy.arn
}

resource "aws_lambda_function" "test_privatelink_lambda" {
  filename         = data.archive_file.pg_privatelink_test_zip_archive.output_path
  function_name    = "PgTestPrivateLink"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "pg-test-privatelink"
  runtime          = "go1.x"
  source_code_hash = filebase64sha256(data.archive_file.pg_privatelink_test_zip_archive.output_path)
  timeout          = 30

  vpc_config {
    security_group_ids = [
      aws_security_group.psql_outbound.id,
    ]

    subnet_ids = [
      aws_subnet.subnet_1.id,
      aws_subnet.subnet_2.id,
    ]
  }

  depends_on = [aws_iam_role_policy_attachment.pg_privatelink_role_to_policy]
}

resource "aws_vpc" "privatelink_example_vpc" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "privatelink_example_vpc"
  }
}

resource "aws_subnet" "subnet_1" {
  vpc_id     = aws_vpc.privatelink_example_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_2" {
  vpc_id     = aws_vpc.privatelink_example_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_security_group" "allow_psql" {
  name        = "allow_psql"
  description = "Allow Postgres traffic from private link"
  vpc_id      = aws_vpc.privatelink_example_vpc.id

  ingress {
    description      = "Allow Postgres/Pgbouncer traffic"
    from_port        = 5332
    to_port          = 5433
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Allow SSH traffic"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "psql_outbound" {
  name        = "psql_outbound"
  description = "Allow Postgres traffic from private link"
  vpc_id      = aws_vpc.privatelink_example_vpc.id

  egress {
    description      = "Allow Postgres/Pgbouncer traffic"
    from_port        = 5332
    to_port          = 5433
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_endpoint" "postgres_privatelink" {
  vpc_id            = aws_vpc.privatelink_example_vpc.id
  service_name      = herokux_privatelink.pg_privatelink.service_name
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.allow_psql.id,
  ]

  subnet_ids = [
    aws_subnet.subnet_1.id,
    aws_subnet.subnet_2.id,
  ]

  tags = {
    Name = "privatelink_example_endpoint"
  }
}

output "privatelink_postgres_status" {
  value = local.postgres_connection_result["status"]
}

output "privatelink_pgbouncer_status" {
  value = local.pgbouncer_connection_result["status"]
}
