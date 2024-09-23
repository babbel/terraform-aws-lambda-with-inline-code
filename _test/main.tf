provider "aws" {
  region = "local"
}

module "lambda" {
  source = "./.."

  function_name = "example"
  description   = "This is an example"

  runtime                        = "nodejs12.x"
  handler                        = "index.handler"
  memory_size                    = 128
  timeout                        = 3
  reserved_concurrent_executions = 1

  environment_variables = {
    NODE_ENV = "production"
  }

  source_dir = "lambda/src"

  tags = {
    app = "example"
    env = "production"
  }
}
