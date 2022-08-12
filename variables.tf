variable "archive_file" {
  type = object({
    output_path         = string
    output_base64sha256 = string
  })
  default = null

  description = "An instance of the `archive_file` data source containing the code of the Lambda function. Conflicts with `source_dir`."
}

variable "cloudwatch_log_group_retention_in_days" {
  type    = number
  default = 3

  description = "The number of days to retain the log of the Lambda function."
}

variable "description" {
  type = string

  description = "Description of the Lambda function."
}

variable "environment_variables" {
  type    = map(string)
  default = null

  description = "Environment variable key-value pairs."
}

variable "function_name" {
  type = string

  description = "Name of the Lambda function."
}

variable "handler" {
  type = string

  description = "The name of the method within your code that Lambda calls to execute your function."
}

variable "layers" {
  type    = list(string)
  default = []

  description = "List of up to five Lambda layer ARNs."
}

variable "memory_size" {
  type = number

  description = "The amount of memory (in MB) available to the function at runtime. Increasing the Lambda function memory also increases its CPU allocation."
}

variable "reserved_concurrent_executions" {
  type = number

  description = "The number of simultaneous executions to reserve for the Lambda function."
}

variable "runtime" {
  type = string

  description = "The identifier of the Lambda function [runtime](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html)."
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

  description = "Path of the directory which shall be packed as code of the Lambda function. Conflicts with `archive_file`."
}

variable "tags" {
  type    = map(string)
  default = {}

  description = "Tags which will be assigned to all resources."
}

variable "timeout" {
  type = number

  description = "The amount of time (in seconds) per execution before stopping it."
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
