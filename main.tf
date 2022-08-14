resource "aws_lambda_function" "this" {
  function_name = var.function_name
  description   = var.description

  runtime                        = var.runtime
  handler                        = var.handler
  memory_size                    = var.memory_size
  timeout                        = var.timeout
  reserved_concurrent_executions = var.reserved_concurrent_executions

  layers = var.layers

  role = aws_iam_role.this.arn

  dynamic "environment" {
    // local.environments is built using a merge, and merges always result in a map
    // so we can safely assume we're dealing with a map here.
    for_each = length(local.environment_variables) > 0 ? [{ variables = local.environment_variables }] : []

    content {
      variables = environment.value.variables
    }
  }

  filename         = try(var.archive_file.output_path, data.archive_file.this[0].output_path)
  source_code_hash = try(var.archive_file.output_base64sha256, data.archive_file.this[0].output_base64sha256)

  tags = var.tags

  depends_on = [
    aws_cloudwatch_log_group.this,
    null_resource.watch_iam_role_policy_secretsmanager_get_secret_value,
  ]
}

data "archive_file" "this" {
  count = var.archive_file != null ? 0 : 1

  type        = "zip"
  source_dir  = var.source_dir
  output_path = ".terraform/tmp/lambda/${var.function_name}.zip"
}

# IAM role

resource "aws_iam_role" "this" {
  name = "lambda-${var.function_name}"

  assume_role_policy = data.aws_iam_policy_document.lambda-assume-role.json

  tags = var.tags
}

data "aws_iam_policy_document" "lambda-assume-role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# CloudWatch Logs group

resource "aws_cloudwatch_log_group" "this" {
  name = "/aws/lambda/${var.function_name}"

  retention_in_days = var.cloudwatch_log_group_retention_in_days

  tags = var.tags
}

data "aws_iam_policy_document" "cloudwatch-log-group" {
  statement {
    actions   = ["logs:DescribeLogStreams"]
    resources = ["${join(":", slice(split(":", aws_cloudwatch_log_group.this.arn), 0, 5))}:*"]
  }

  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }
}

resource "aws_iam_role_policy" "cloudwatch-log-group" {
  role   = aws_iam_role.this.name
  name   = "cloudwatch-log-group"
  policy = data.aws_iam_policy_document.cloudwatch-log-group.json
}

# VPC config

locals {
  # convert `var.vpc_config` into a `for_each`-compatible local
  vpc_config_key = "lambda"
  vpc_configs    = var.vpc_config != null ? { (local.vpc_config_key) = var.vpc_config } : {}
}

resource "aws_security_group" "this" {
  for_each = local.vpc_configs

  name        = "lambda-${var.function_name}"
  description = "Lambda: ${var.function_name}"
  vpc_id      = each.value.vpc.id

  tags = merge({
    Name = "Lambda: ${var.function_name}"
  }, var.tags)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "egress" {
  for_each = aws_security_group.this

  security_group_id = each.value.id

  type        = "egress"
  cidr_blocks = ["0.0.0.0/0"]
  protocol    = "-1"
  from_port   = 0
  to_port     = 0

  lifecycle {
    create_before_destroy = true
  }
}

# Secret environment variables

locals {
  environment_variables = merge(var.environment_variables, local.secret_environment_variables)

  secret_environment_variables = {
    for k, v in var.secret_environment_variables : join("", [k, "_SECRET_ARN"]) => v
  }
}

resource "aws_iam_role_policy" "secretsmanager-get-secret-value" {
  count = length(var.secret_environment_variables) > 0 ? 1 : 0

  name   = "secretsmanager-get-secret-value-${md5(data.aws_iam_policy_document.secretsmanager-get-secret-value[count.index].json)}"
  role   = aws_iam_role.this.name
  policy = data.aws_iam_policy_document.secretsmanager-get-secret-value[count.index].json

  lifecycle {
    create_before_destroy = true
  }
}

# Whenever a change is made to the secrets, the role policy must be updated
# first, then we need to wait for a few seconds and only then update the lambda function itself.
# Waiting is necessary because otherwise the during initialization of the lambda function
# it will not yet have the permissions for fetching the secret values.
resource "null_resource" "watch_iam_role_policy_secretsmanager_get_secret_value" {
  count = length(var.secret_environment_variables) > 0 ? 1 : 0

  # null_resource is replaced every time the policy changes
  triggers = {
    secretsmanager_get_secret_value_policy = aws_iam_role_policy.secretsmanager-get-secret-value[count.index].policy
  }

  provisioner "local-exec" {
    command = "sleep 15"
  }
}

data "aws_iam_policy_document" "secretsmanager-get-secret-value" {
  count = length(var.secret_environment_variables) > 0 ? 1 : 0

  statement {
    actions = ["secretsmanager:GetSecretValue"]

    # select secret arns and cut off trailing json keys
    # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data-secrets.html
    resources = [
      for k, extended_secret_arn in local.secret_environment_variables :
      join(":", slice(split(":", extended_secret_arn), 0, 7)) if length(regexall("_SECRET_ARN$", k)) == 1
    ]
  }
}
