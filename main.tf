resource "aws_lambda_function" "this" {
  function_name = var.function_name
  description   = var.description

  runtime                        = var.runtime
  handler                        = var.handler
  memory_size                    = var.memory_size
  timeout                        = var.timeout
  reserved_concurrent_executions = var.reserved_concurrent_executions

  layers = local.secrets_wrapper_layers

  role = aws_iam_role.this.arn

  dynamic "environment" {
    for_each = local.environment_variables != null ? [{ variables = local.environment_variables }] : []

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

resource "aws_iam_role_policy" "cloudwatch-log-group" {
  role   = aws_iam_role.this.name
  name   = "cloudwatch-log-group"
  policy = data.aws_iam_policy_document.cloudwatch-log-group.json
}

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


# Secret environment variables

locals {
  environment_variables = merge(local.lambda_exec_wrapper, var.environment_variables, local.secret_environment_variables)

  lambda_exec_wrapper = length(var.secret_environment_variables) == 0 ? {} : {
    AWS_LAMBDA_EXEC_WRAPPER = "/opt/main"
  }

  secret_environment_variables = {
    for k, v in var.secret_environment_variables : join("", [k, "_SECRET_ARN"]) => v
  }

  secrets_wrapper_layers = length(var.secret_environment_variables) <= 0 ? [] : [
    # sets the number suffix of lambda-layer version secrets.wrapper.lambda-layer.
    # cf. https://github.com/lessonnine/secrets.wrapper.lambda-layer#readme
    "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:layer:secrets_wrapper:${var.secrets_wrapper_lambda_layer_version_number}"
  ]
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

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
# Waiting is necessary because otherwise the during initialization of the lambda function the
# secrets-fetcher wrapper will not yet have the permissions for fetching the secret values.
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
