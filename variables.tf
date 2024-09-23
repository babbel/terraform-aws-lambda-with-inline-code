variable "archive_file" {
  type = object({
    output_path         = string
    output_base64sha256 = string
  })
  default = null

  description = <<EOS
An instance of the `archive_file` data source containing the code of the Lambda function. Conflicts with `source_dir`.
EOS
}

variable "cloudwatch_log_group_retention_in_days" {
  type    = number
  default = 3

  description = <<EOS
The number of days to retain the log of the Lambda function.
EOS
}

variable "description" {
  type = string

  description = <<EOS
Description of the Lambda function.
EOS
}

variable "environment_variables" {
  type    = map(string)
  default = null

  description = <<EOS
Environment variable key-value pairs.
EOS
}

variable "function_name" {
  type = string

  description = <<EOS
Name of the Lambda function.
EOS
}

variable "handler" {
  type = string

  description = <<EOS
The name of the method within your code that Lambda calls to execute your function.
EOS
}

variable "layers" {
  type    = list(string)
  default = []

  description = <<EOS
List of up to five Lambda layer ARNs.
EOS
}

variable "memory_size" {
  type = number

  description = <<EOS
The amount of memory (in MB) available to the function at runtime. Increasing the Lambda function memory also increases its CPU allocation.
EOS
}

variable "reserved_concurrent_executions" {
  type = number

  description = <<EOS
The number of simultaneous executions to reserve for the Lambda function.
EOS
}

variable "runtime" {
  type = string

  description = <<EOS
The identifier of the Lambda function [runtime](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html).
EOS
}

variable "secret_environment_variables" {
  type    = map(string)
  default = {}

  description = <<EOS
Map of environment variable names to ARNs of AWS Secret Manager secrets.

Each ARN will be passed as environment variable to the lambda function with the key's name extended by suffix _SECRET_ARN. When initializing the Lambda run time environment, the Lambda function or a [wrapper script](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-modify.html#runtime-wrapper) can look up the secret value.

Permission will be added allowing the Lambda function to read the secret values.
EOS
}

variable "source_dir" {
  type    = string
  default = null

  description = <<EOS
Path of the directory which shall be packed as code of the Lambda function. Conflicts with `archive_file`.
EOS
}

variable "tags" {
  type    = map(string)
  default = {}

  description = <<EOS
Map of tags assigned to all AWS resources created by this module.
EOS
}

variable "timeout" {
  type = number

  description = <<EOS
The amount of time (in seconds) per execution before stopping it.
EOS
}

variable "vpc_config" {
  type = object({
    subnets = list(
      object({
        arn = string
        id  = string
      })
    )
    vpc = object({
      id = string
    })
  })
  default = null

  description = <<EOS
VPC configuration of the Lambda function:

* `subnets`: List of subnets in which the Lambda function will be running. The subnets must be in the VPC specified by `vpc`.
* `vpc`: The VPC in which the Lambda function will be running and where all VPC-related resources (e.g. the security group) will be located.

If `vpc_config` is `null` the Lambda function will not be placed into a VPC.
EOS
}
