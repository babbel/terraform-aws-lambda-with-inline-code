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
    for_each = var.environment_variables != null ? [{ variables = var.environment_variables }] : []

    content {
      variables = environment.value.variables
    }
  }

  filename         = try(var.archive_file.output_path, data.archive_file.this[0].output_path)
  source_code_hash = try(var.archive_file.output_base64sha256, data.archive_file.this[0].output_base64sha256)

  tags = var.tags

  depends_on = [aws_cloudwatch_log_group.this]
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
