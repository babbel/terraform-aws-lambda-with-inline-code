output "this" {
  value = aws_lambda_function.this

  description = "The Lambda function."
}

output "cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.this

  description = "The CloudWatch Logs group the Lambda function use for its logs."
}

output "iam_role" {
  value = aws_iam_role.this

  description = "The IAM role the Lambda function will assume."
}

output "security_group" {
  value = lookup(aws_security_group.this, local.vpc_config_key, null)

  description = "The VPC security group the Lambda function will use if `var.vpc_config` is specified; `null` otherwise."
}
